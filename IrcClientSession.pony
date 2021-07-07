use "net"
use "time"
use "debug"
use "buffered"
use "collections"
use "matrixclient"

primitive PendingIRCAuth
primitive PendingMatrixAuth
primitive FullyAuthed
type ClientState is (PendingIRCAuth | PendingMatrixAuth | FullyAuthed)

actor IrcClientSession
  var auth: AmbientAuth
  var ircnick: String = ""  // Nickname
  var ircuser: String = ""  // The user@host
  var userstate: ClientState = PendingIRCAuth  // FSMesque
  var readerBuffer: Reader ref = Reader // Used to break data into
                                        // line-based events.
  let timers: Timers = Timers
  let conn: TCPConnection

  var matrixclient: (MatrixClient|None) = None


  new create(conn': TCPConnection, auth': AmbientAuth) =>
    auth = auth'
    conn = conn'


  be connect_matrix(token: String val) =>
    matrixclient = MatrixClient(auth, "https://evil.red:8448", token)
    var thistag: IrcClientSession tag = this
    match matrixclient
    | let mc: None => None
    | let mc: MatrixClient => mc.whoami(thistag~gotwhoami())
    end


  be gotwhoami(decoder: DecodeType val, json: String) =>
    Debug.out("Got whoami")
    try
      let uid: String = (decoder as WhoAmI val).apply(json)?
      send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :You are now logged in via matrix user: " + uid)
      this.initialsync()
    else
      send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :Your token appears to be invalid. Sucks to be you")
    end

  be initialsync() =>
    var thistag: IrcClientSession tag = this
    match matrixclient
    | let mc: None => None
    | let mc: MatrixClient => mc.sync(thistag~gotinitialsync())
    end


  be gotinitialsync(decoder: DecodeType val, json: String) =>
   try
//     match decoder
 //    | let x: MSync val => send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :MSStart of channel list")
 //    end
     (let aliasmap: Map[String, String], let nb: String) = (decoder as MSync val).apply(json)?
     for f in aliasmap.keys() do
       send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :" + f)
     end
     send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :End of channel list")
   else
     send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :" + "Failed in gotinitialsync")
     send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :" + json)
   end

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
    send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :Please send me your matrix token")
    send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :/msg matrixproxy HELP for help")
    send_data(":matrixproxy!matrixproxy@matrixproxy PRIVMSG " + ircnick + " :/msg matrixproxy TOKEN <token> to connect to Matrix")

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

  be privmsg(line: String iso) =>
    Debug.out("Got me a privmsg line: " + consume line)

  be botmessage(line: String val) =>
//    let l: Array[String] = line.split(" ")
    try
      match line.split(" ").apply(2)?
      | let l: String val if (l == ":TOKEN") =>
        connect_matrix(line.split(" ").apply(3)?)
      end
    end

  // Process the incoming line
  be incoming_line(line: String iso, times: USize) =>
    Debug.out("<< " + line.clone())
    match consume line
    | let l: String iso if (l.substring(0,8) == "PRIVMSG ") =>
      try
        match l.split(" ").apply(1)?
        | let nick: String if (nick.lower() == "matrixproxy") =>
            this.botmessage(consume l)
        | let x: String => this.privmsg(consume l)
      end
    end
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
