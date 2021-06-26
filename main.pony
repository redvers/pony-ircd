use "net"
use "debug"
use "buffered"
use "matrixclient"

actor Main
  new create(env: Env) =>
    let port: String = "6667"
    try
      // Start the TCPListener Actor for plaintext port 6667
      TCPListener(env.root as AmbientAuth, recover PlaintextTCPListener end, "", port)
    end


/* The TCPListener actor will call callbacks in this module as each
 * thing happens.                                                     */
class PlaintextTCPListener is TCPListenNotify
/* Called when a client successfully opens a connection.  It provides
 * the class that is used for callbacks for the traffic in/out etc... */
  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    IrcClientPlumbing

  // Called if the TCP Connection fails to LISTEN
  fun ref not_listening(listen: TCPListener ref) =>
    None


/* When a connection is successfully made, a new actor is spawned
 * and this class contains the callbacks.
 *
 * As incoming text can come in in any size blocks (ie, not line
 * terminated I'm passing the data into the dedicated IrcClientSession
 * actor.                                                             */
class IrcClientPlumbing is TCPConnectionNotify
  var clientactor: IrcClientSession tag = IrcClientSession

  // Connection has been made, sending the server MOTD
  fun ref accepted(conn: TCPConnection): None =>
    clientactor.motd(conn)

  // Received a chunk of network data...
  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    // Sending the block of data to the dedicated actor
    clientactor.recv_data(conn, consume data, times)
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

