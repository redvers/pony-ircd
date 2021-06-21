use "net"
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

  new create() =>
    None

  be motd(conn: TCPConnection) =>
    conn.write(":localhost Welcome to WHATTHEHELLAMIDOING proxy\r\n")
    conn.write(":localhost Expect to have to login at some point\r\n")

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


  // Process the incoming line
  be incoming_line(conn: TCPConnection, line: String iso, times: USize) =>
    Debug.out("<[" + (digestof this).string() + "]" + consume line)


