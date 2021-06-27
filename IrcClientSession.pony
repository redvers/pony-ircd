use "net"
use "time"
use "debug"
use "buffered"

primitive PendingIRCAuth
primitive PendingMatrixAuth
primitive FullyAuthed
type ClientState is (PendingIRCAuth | PendingMatrixAuth | FullyAuthed)

actor IrcClientSession
  var ircnick: String = ""  // Nickname
  var ircuser: String = ""  // The user@host
  var userstate: ClientState = PendingIRCAuth  // FSMesque
  var readerBuffer: Reader ref = Reader // Used to break data into
                                        // line-based events.
  let timers: Timers = Timers

  new create() =>
    None

  be intro(conn: TCPConnection) =>
    conn.write(":matrixproxy 001 " + ircnick + " :Welcome to the matrixproxy " + ircnick + "!" + ircuser + "\r\n")
    conn.write(":matrixproxy 002 " + ircnick + " :Your host is matrixproxy\r\n")
    conn.write(":matrixproxy 003 " + ircnick + " :This server was created just now\r\n")
    conn.write(":matrixproxy 375 " + ircnick + " :- matrixproxy Message of the day -\r\n")
    conn.write(":matrixproxy 372 " + ircnick + " :- Please await instructions...\r\n")
    conn.write(":matrixproxy 376 " + ircnick + " :End of message of the day.\r\n")

    let thistag: IrcClientSession tag = this
    let timer: Timer iso = Timer(PNotify(thistag, conn), 5_000_000_000, 20_000_000_000)
    timers(consume timer)

  be sendping(conn: TCPConnection) =>
    conn.write("PING something\r\n")


  be recv_data(conn: TCPConnection, data: Array[U8] iso, times: USize) =>
    var dstring: String iso = String.from_iso_array(consume data)
    // Append the block of data to our Reader buffer
    readerBuffer.append(consume dstring)

    while (true) do
      try
        // See if I can pull a full line out of the buffer
        let line: String iso = readerBuffer.line()?

        // Send that line to myself as an asych message
        incoming_line(conn, consume line, times)
      else
        // If there isn't a full line of text available, we
        // break out of the while true loop.
        break
      end
    end


  // CAP LS
  // NICK red
  // USER red red localhost :Unknown

  // Process the incoming line
  be incoming_line(conn: TCPConnection, line: String iso, times: USize) =>
    Debug.out(">> " + line.clone())
    match consume line
//    | let l: String iso if (l.substring(0,18) == "PRIVMSG localhost ") =>
//      try
//        let token: String = l.split(" ").apply(2)?
//        Debug.out("Got matrix token: " + token)
//        conn.write("PRIVMSG bob!bob@localhost :" + token + "\r\n")
//      end
    | let l: String iso if (l.substring(0,5) == "PING ") =>
      try
        let replystr: String = l.split(" ").apply(1)?
        conn.write("PONG " + replystr + "\r\n")
      end
    | let l: String iso if (l.substring(0,5) == "NICK ") =>
      try
        ircnick = l.split(" ").apply(1)?
      end
    | let l: String iso if (l.substring(0,5) == "USER ") =>
      let uarray: Array[String] = l.split_by(" ")
      try
        ircuser = uarray.apply(1)? + "@" + uarray.apply(2)?
        ircnick = uarray.apply(1)?
        this.intro(conn)
      end
//    | let l: String iso if (l.substring(0,5) == "JOIN ") =>
//      let uarray: Array[String] = l.split_by(" ")
//      try
//        let newchan: String = uarray.apply(1)?
//        conn.write(":" + ircnick + "!" + ircuser + " JOIN :" + newchan + "\r\n")
//        conn.write(":localhost 353 " + ircnick + " = " + newchan + ":Some New Users\r\n")
//        conn.write(":localhost 366 " + ircnick + " = " + newchan + ":End of /NAMES list\r\n")
//      end
    | let l: String iso if (l.substring(0,8) == "USERHOST") =>
      let uarray: Array[String] = l.split_by(" ")
      try
        if(uarray.apply(1)? == ircuser) then
          // lkjhlkjhlikjh=+~red@cpe-69-132-182-159.carolina.res.rr.com
          conn.write(":matrixproxy 302 " + ircnick + "=+" + ircuser + "\r\n")
//          conn.write(":localhost 318 " + ircnick + " " + ircnick + ":End of /WHOIS list.\r\n")
        end
      end
    | let l: String iso => Debug.out("<[" + (digestof this).string() + "]" + consume l)
    end


class PNotify is TimerNotify
  let itag: IrcClientSession tag
  let conn: TCPConnection

  new iso create(itag': IrcClientSession tag, conn': TCPConnection) =>
    conn = conn'
    itag = itag'

  fun ref apply(timer: Timer, count: U64): Bool =>
    itag.sendping(conn)
    true
