use "net"
use "debug"
use "buffered"

actor IrcClientSession
  var readerBuffer: Reader ref = Reader

  new create() =>
    None

  be recv_data(conn: TCPConnection, data: Array[U8] iso, times: USize) =>
    var dstring: String iso = String.from_iso_array(consume data)
    readerBuffer.append(consume dstring)

    while (true) do
      try
        let line: String iso = readerBuffer.line()?
        incoming_line(conn, consume line, times)
      else
        break
      end
    end

  be incoming_line(conn: TCPConnection, line: String iso, times: USize) =>
    Debug.out("<[" + times.string() + "]" + consume line)


