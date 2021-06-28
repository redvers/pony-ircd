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
  let conn: TCPConnection


  new create(conn': TCPConnection) =>
    conn = conn'

  be send_data(line: String) =>
    Debug.out(">> " + line.clone())
    conn.write(line + "\r\n")

  be intro() =>
    send_data(":matrixproxy 001 " + ircnick + " :Welcome to the matrixproxy " + ircnick + "!" + ircuser)
    send_data(":matrixproxy 002 " + ircnick + " :Your host is matrixproxy")
    send_data(":matrixproxy 003 " + ircnick + " :This server was created just now")
    send_data(":matrixproxy 375 " + ircnick + " :- matrixproxy Message of the day -")
    send_data(":matrixproxy 372 " + ircnick + " :- Please await instructions...")
    send_data(":matrixproxy 376 " + ircnick + " :End of message of the day.")

    let thistag: IrcClientSession tag = this
    let timer: Timer iso = Timer(PNotify(thistag), 5_000_000_000, 20_000_000_000)
    timers(consume timer)

  be sendping() =>
    send_data("PING something")


  be recv_data(data: Array[U8] iso, times: USize) =>
    var dstring: String iso = String.from_iso_array(consume data)
    // Append the block of data to our Reader buffer
    readerBuffer.append(consume dstring)

    while (true) do
      try
        // See if I can pull a full line out of the buffer
        let line: String iso = readerBuffer.line()?

        // Send that line to myself as an asych message
        incoming_line(consume line, times)
      else
        // If there isn't a full line of text available, we
        // break out of the while true loop.
        break
      end
    end

  // Process the incoming line
  be incoming_line(line: String iso, times: USize) =>
    Debug.out("<< " + line.clone())
    match consume line
    | let l: String iso if (l.substring(0,5) == "PONG ") => None
    | let l: String iso if (l.substring(0,5) == "PING ") =>
      try
        let replystr: String = l.split(" ").apply(1)?
        send_data("PONG " + replystr)
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
        this.intro()
      end
    | let l: String iso if (l.substring(0,8) == "USERHOST") =>
      let uarray: Array[String] = l.split_by(" ")
      try
        if(uarray.apply(1)? == ircnick) then
          // lkjhlkjhlikjh=+~red@cpe-69-132-182-159.carolina.res.rr.com
          send_data(":matrixproxy 302 " + ircnick + " :" + ircnick + "=+" + ircuser)
        end
      end
    | let l: String iso => Debug.out("<[" + (digestof this).string() + "]" + consume l)
    end


class PNotify is TimerNotify
  let itag: IrcClientSession tag

  new iso create(itag': IrcClientSession tag) =>
    itag = itag'

  fun ref apply(timer: Timer, count: U64): Bool =>
    itag.sendping()
    true
