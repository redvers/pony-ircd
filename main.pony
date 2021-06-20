use "net"
use "debug"
use "buffered"

actor Main
  new create(env: Env) =>
    try
      TCPListener(env.root as AmbientAuth, recover PlaintextTCPListener end, "", "6667")
    end

class IrcClientPlumbing is TCPConnectionNotify
  var clientactor: IrcClientSession tag = IrcClientSession
  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    clientactor.recv_data(conn, consume data, times)
    true


  fun ref connect_failed(conn: TCPConnection ref) =>
    None

class PlaintextTCPListener is TCPListenNotify
  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    IrcClientPlumbing

  fun ref not_listening(listen: TCPListener ref) =>
    None


