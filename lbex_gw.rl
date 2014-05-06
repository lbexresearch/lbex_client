/*
 * State machine definition for the lbex order entry gw.
 *
 * Command interface
 *
 * The client use epoll for socket polling, see :
 * http://man7.org/tlpi/code/online/dist/altio/epoll_input.c.html
 * Changed to poll after reading this.
 * http://www.ulduzsoft.com/2014/01/select-poll-epoll-practical-difference-for-system-architects/
 * http://pic.dhe.ibm.com/infocenter/iseries/v6r1m0/index.jsp?topic=/rzab6/poll.htm
 *
 * 0.   If autoconnect = true, goto 3.
 * 1.   Wait for connection on the command interface.
 * 2.   Verify username and password.
 * 3.   Connect to exchange.
 * 4.   Manage orders.
 * 4.1 
 * 
 * 7.1 Disconnect from exchange
 * 7.2 Shutdown process.
 *
 *
 *   clnt orderReq  --> lbex_gw --> order_table --> order exchange
 *   clnt orderAck  <-- lbex_gw <-- order_table <-- ack   exchange
 *   clnt orderMat  <-- lbex_gw <-- order_table <-- match exchange
                                        match_table <-|
 *   clnt cancelOrd --> lbex_gw -->             --> cancel exchange
 *   clnt canelAcl  <-- lbex_gw <-- order_table <-- cancelled exchange
 *
 * http://beej.us/guide/bgnet/output/html/singlepage/bgnet.html#pollman
 */ 

#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <poll.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>
#include <errno.h>

#include "logger.h"

#define AUTO_CONNECT = 0
#define MAXEVENTS 64

%%{
  machine clnt_if;

  action do_enter_order {
    printf("Enter order : \n");
  }

  action anything {
    _DEBUG("State: %d, ( %i -> %i ) char: %c\n", cs, fcurs, ftargs, *p );
  }

  action do_connect {
    printf("Connect\n");
  }

  action do_disconnect {
    printf("Disconnect\n");
  }

  action do_shutdown {
    printf("Shutdown\n");
    exit( 0 );
  }
 
  action buy_order {
    printf("Buy : \n");
  }

  action sell_order {
    printf("Sell : \n");
  }

 
  connect      = 'connect' >do_connect $anything;
  disconnect   = 'disconnect' >do_disconnect $anything;
  shutdown     = 'shutdown' >do_shutdown $anything;
  buy          = 'B' digit{12} alnum{4} digit{10} >buy_order $anything;
  sell         = 'S' digit{12} alnum{4} digit{10} >sell_order $anything;
  failover     = 'failover';
  node         ="[ABC]";

  main := ( connect | disconnect | buy | sell )* shutdown;
}%%


%%{
  machine burp_feed;

  action enter_order {
    printf("Handle order\n");
  }

  action cancel_order {
    printf("Cancel Order\n");
  } 

  action enter_quote {
    printf("Enter Quote\n");
  }

  orderid    = alnum{14};
  quantity   = digit{12};
  instrument = alnum{8};
  price      = digit{10};
  bid_price  = price;
  ask_price  = price;

  order      = "[BS] quantity instrument@price DAY" > enter_order;
  cancel     = "C orderid orderid" > cancel_order;
  quote      = "Q bid_price ask_price quantity instrument price spread" > enter_quote;
  heartbeat  = 0xFC; 
  request    = orderid order | cancel | quote;

  main := ( order | cancel )*;

}%%



/*
 * @brief parser for the clinet interface to the gw
 *
 * 
 *
 */
int parse_clnt_if( char *buffer, int length )
{
  // char buffer[] = "connectdisconnectconnectshutdown";
  char *p;
  static int cs = 1;
  char *pe, *eof;

  printf("1 parse_ctrl_if, cs = %d\n", cs); 
  
  %% machine clnt_parser;
  %% write data;

  %% include clnt_if;
  p = buffer;
  pe = buffer + length;
  %%{
    write init;
    write exec;
  }%%
  printf("2 parse_ctrl_if, cs = %d\n", cs);
}



int parse_burp_if( char *buffer, int length )
{
  // char buffer[] = 'B';
  char *p; 
  int  cs; 
  char *pe, *eof;

  printf("parse_burp_if : \n"); 
  
  %% machine burp_parser;
  %% write data;

  %% include burp_feed;
  p = buffer;
  pe = buffer + length; 
  %%{ 
    write init;
    write exec;
  }%%  
   

}


static int
make_socket_non_blocking (int sfd)
{
  int flags, s;

  flags = fcntl (sfd, F_GETFL, 0);
  if (flags == -1)
    {
      perror ("fcntl");
      return -1;
    }

  flags |= O_NONBLOCK;
  s = fcntl (sfd, F_SETFL, flags);
  if (s == -1)
    {
      perror ("fcntl");
      return -1;
    }

  return 0;
}

/*
 * @brief connect to exchange
 *
 * Return filedescriptor.
 *
 */
static int
connect_to( char* ip, int port )
{
  int fd;
  int sock;
  
  log_info("Connection to me on : %s %d\n", ip, port);  

  sock=socket(AF_INET,SOCK_STREAM, 0);
  sockaddr_in serverAddress;
  serverAddress.sin_family=AF_INET;
  serverAddress.sin_port=htons(port);
  serverAddress.sin_addr.s_addr=inet_addr(ip);

  fd = connect(sock ,(struct sockaddr *) &serverAddress,sizeof(serverAddress));
  log_info("FD to EXCH : %d\n", fd );
  return( fd );
}



/*
 * @brief Create the control socket.
 */  
static int
create_client_socket ( int port )
{
  struct addrinfo hints;
  struct addrinfo *result, *rp;
  int s, sfd;
  char portt[] = "6500";

  memset (&hints, 0, sizeof (struct addrinfo));
  hints.ai_family   = AF_UNSPEC;     /* Return IPv4 and IPv6 choices */
  hints.ai_socktype = SOCK_STREAM;   /* We want a TCP socket */
  hints.ai_flags    = AI_PASSIVE;    /* All interfaces */

  s = getaddrinfo (NULL, portt, &hints, &result);
  if (s != 0)
    {
      fprintf (stderr, "getaddrinfo: %s\n", gai_strerror (s));
      return -1;
    }

  for (rp = result; rp != NULL; rp = rp->ai_next)
    {
      sfd = socket (rp->ai_family, rp->ai_socktype, rp->ai_protocol);
      if (sfd == -1)
        continue;

      s = bind (sfd, rp->ai_addr, rp->ai_addrlen);
      if (s == 0)
        {
          /* We managed to bind successfully! */
          break;
        }

      close (sfd);
    }

  if (rp == NULL)
    {
      fprintf (stderr, "Could not bind\n");
      return -1;
    }

  freeaddrinfo (result);

  s = make_socket_non_blocking (sfd);
  if (s == -1)
    abort ();

  s = listen (sfd, SOMAXCONN);
  if (s == -1)
  {
    perror ("listen");
    abort ();
  }

  return sfd;
}

int join_mc_gr( char* ip, int port )
{
  struct sockaddr_in localSock;
  struct ip_mreq group;
  int sd;
  int datalen;
  char databuf[1024];

  /* Create a datagram socket on which to receive. */
  sd = socket(AF_INET, SOCK_DGRAM, 0);
  if(sd < 0)
  {
    perror("Opening datagram socket error");
    exit(1);
  }
  else
  printf("Opening datagram socket....OK.\n");
 
  /* Enable SO_REUSEADDR to allow multiple instances of this */
  /* application to receive copies of the multicast datagrams. */
  {
    int reuse = 1;
    if(setsockopt(sd, SOL_SOCKET, SO_REUSEADDR, (char *)&reuse, sizeof(reuse)) < 0)
    {
      perror("Setting SO_REUSEADDR error");
      close(sd);
      exit(1);
    }
    else
      printf("Setting SO_REUSEADDR...OK.\n");
    }
 
    /* Bind to the proper port number with the IP address */
    /* specified as INADDR_ANY. */
    memset((char *) &localSock, 0, sizeof(localSock));
    localSock.sin_family = AF_INET;
    localSock.sin_port = htons(port);
    localSock.sin_addr.s_addr = INADDR_ANY;
    if(bind(sd, (struct sockaddr*)&localSock, sizeof(localSock)))
    {
      perror("Binding datagram socket error");
      close(sd);
      exit(1);
    }
    else
      printf("Binding datagram socket...OK.\n");
 
      /* Join the multicast group 226.1.1.1 on the local 203.106.93.94 */
      /* interface. Note that this IP_ADD_MEMBERSHIP option must be */
      /* called for each local interface over which the multicast */
      /* datagrams are to be received. */
      group.imr_multiaddr.s_addr = inet_addr( ip );
      // group.imr_interface.s_addr = inet_addr("192.168.2.42");
      // group.imr_interface.s_addr = inet_addr("192.168.0.3");
      if(setsockopt(sd, IPPROTO_IP, IP_ADD_MEMBERSHIP, (char *)&group, sizeof(group)) < 0)
      {
        perror("Adding multicast group error");
        close(sd);
        exit(1);
      }
      else
      printf("Adding multicast group...OK.\n");
 
      /* Read from the socket. */
/*      datalen = sizeof(databuf);
      int n = read(sd, databuf, datalen);
      if( n < 0)
      {
        perror("Reading datagram message error");
        close(sd);
        exit(1);
      }
      else
      {
        printf("Reading datagram message...OK.\n");
        printf("The message from multicast server is: \"%x %x\" %d\n", databuf[0], databuf[1], n);
      } */
  return sd;
}

/*
 * @brief Wait for control connection.
 *
 * First message must be username/password
 */

int verify_login( int fd )
{
  char buf[] = "user01testonly";

  log_info("Waiting for connection on fd %i\n", fd );
   
  if( strncmp( buf, "user01", 6 ) == 0 )
  {
    if( strncmp( buf + 6, "testonly", 8 ) == 0 )
    {
      return 0;
    }
    return 1;
  }
  return 2;
}


/*
 * @brief Lbex .
 *
 * Initially :
 *
 * 1.0 Start the gateway.

 * 2.  Check for recovery file
 * 2.1 Parse recovery file is present, populate internal data structures.

 * 1.1 Join the me multicast feed.




 * 1.2 Wait for a heartbeat.
 * 1.3 Connect to the exchange order management port.
 * 
 * 2.2 Wait for SOD and and then populate the gateway with reference data.
 * 
 * 2.0 Listen on ctrl_port and :
 *
 * 2.  Check for recovery file
 * 2.1 Parse recovery file is present, populate internal data structures.
 * 3   Join multicast port listening to the feed.
 * 3.1   If failed to join, exit.
 * 3.2 If there is a sequence number gap, do a rerequest to fill gap.
 *     
 * 4.  Allocate ctrl port, if fail try secondary port, if fail exit.
 * 5.  If autoconnect = 1, connect to exchange.
 * 6.  Wait for connection on the ctrl port.
 * 7.  Connect to exchange.
 * 8.  Wait for SOD
 * 9.  Accept orders
 * 
 *           ----------                     -------------------
 *           |        |--- TCP connection-->|  
 * ---ctrl-->| Client |<-- UDP feed --------| Exchange
 *           |        |                     -------------------
 *           |        |<-- TCP Rerequest -->| Rerequest server         
 *           ----------                     -------------------
 *
 * State    Event     RREQ  CLNT  EXCH  BURP     *    NewState 
 *     0    Start        0     0     0     0     0    Starting 
 * Starting Restart      0     0     0     0     0    Restart
 * Rerq                  1     0     0     1     9    Starting
 * Started  ClConn       0     0     1     1     3    Client Connected 
 * ClConed  LoggedIn     0     1     1     1     8    OrderMgm
 *
 * 
 * Event
 * ctrl connect     connection_status |= CTRL_CONNECTED  fds[CTRL] = 1
 * ctrl disconnect  connection_status ^= CTRL_CONNECTED  fds[CTRL] = 0
 * exch connect     connection_status |= EXCH_CONNECTED  fds[EXCH] = 1
 * exch disconnect  connection_status ^= EXCH_CONNECTED  fds[EXCH] = 0
 * 
 * BURP = 0    0x1   0001 1. Binary mUlticast ? Protocol
 * EXCH = 1    0x2   0010 2. Exchange connection 
 * CLNT = 2    0x4   0100 4  Client connection
 * RREQ = 3    0x8   1000 8  Rerequest server
 * 
 *
 * If ctrl_fd = 0 => No connection on the ctrl port.
 * If exch_fd = 0 => Not connected to the exchange.
 *
 * Poll vill ignore fds[n] that have a value 0.
 * 
 * Nothing connected fds -> listen on ctrl_fd
 * 
 * When ctrl connects
 * 1. Close the listen port, only accept one connection. 
 * 2. Verify login details.
 * 3. Start accepting requests.
 *
 * When ctrl disconnects
 * 1. Close fd.
 * 2. Start listening to the ctrl port again.
 *
 * Order Management
 *
 * struct request {
 *   uint32_t  status; // pending, new, 
 *   void         *req; // order_add, cancel
 * }
 *
 * request request_p[MAX_REQUESTS];
 * uint32_t execution[MAX_INSTRUMENT];
 *   
 *
 * client --> request[n].status = pending       ->     matching_engine
 *            request[n].status = new           <- ack matching_engine
 *            request[n].status = part_fill     <- match 
 *            execution[request->request.instrument] += qty;         
 */

struct connection {
  int status;
  int fd;
};

#define MAX_BUF     1000        /* Maximum bytes fetched by a single read() */
#define TRUE 1
#define FALSE 0
#define BURP 0x01       // Bitmask
#define BURPIX BURP - 1 // Index in the fds array.
#define EXCH 0x02       // 
#define EXCHIX EXCH - 1
#define CLNT 0x03
#define CLNTIX CLNT - 1
#define RREQ 0x04
#define RREQIX 0x04 - 1


main ()
{
  int cmd_fd = 1;
  int trading_fd = 2;
  int s, n;
  int efd;
  int new_sd;
  // const int control_port = 0;
  // const int exch_port = 0;
  int connect_exch = FALSE;
  int connected_ctrl = 0;
  int connected_exch = 0;
  int connection_status = 0;
  int auto_connet = FALSE;
  int sockets = 1;
  int    desc_ready, end_server = FALSE;
  int    close_conn;
  int control_socket;
  int sfd;
  int client_socket;
  int numOpenFds;
  struct pollfd fds[4];
  connection ctrl_connection;
  connection exch_connection;
  
  char buf[1024];
  char clnt_ip[] = "127.0.0.1";
  int  clnt_port = 6500;
  char exch_ip[] = "192.168.0.3";
  int  exch_port = 6003;
  char burp_ip[] = "239.9.9.9";
  int  burp_port  = 7000;
  
  log_info("Starting lbex order gw listening on port : %d\n", clnt_port );

  log_info("Join multicast group %s:%d\n", burp_ip, burp_port );
  sfd = join_mc_gr( burp_ip,  burp_port );
  if( sfd < 0 ) {
    log_err("Failed to join multicast group, shutting down : %d\n", sfd );
    exit( 1 );
  }

  fds[BURPIX].fd = sfd;
  fds[BURPIX].events = POLLIN | POLLPRI;
  fds[BURPIX].revents = 0;
  connection_status |= BURP;

  log_info("Connect to exchange %s:%d\n", exch_ip, exch_port );
  sfd = connect_to( exch_ip, exch_port );
  if( sfd < 0 ) {
    log_err("Failed to connect to exhange, shutting down : %s %d\n", exch_ip, exch_port );
    exit( 1 );
  }
  fds[EXCHIX].fd = sfd;
  fds[EXCHIX].events = POLLIN | POLLPRI;
  connection_status |= EXCH;

  log_info("Creating client socket : %d\n", clnt_port );
  client_socket = create_client_socket( clnt_port );
  if( client_socket < 0 ) {
    log_err("Failed to create client socket, shutting down : %d\n", sfd );
    exit( 1 );
  }
  fds[CLNTIX].fd = client_socket;
  fds[CLNTIX].events = POLLIN | POLLPRI;
   

  fds[RREQIX].fd = -1;
  fds[RREQIX].events = POLLIN;  
 
  // parse_cmd_if( cmd_fd ); 

  while( 1 )
  {
    log_info("Connection status : %d\n", connection_status );
    // If 
  
    int n;
    printf("Waiting for incomming packets, no sockets : %d\n", sockets);
    n = poll(fds, sockets, 10000 );
 
    for( int i = 0; i < 4; i++ )
    {
      printf("fds[%d].revents = %d ( %d )\n", i, fds[i].revents, fds[i].fd );
    }

    log_info("Event on sockets : %d\n", n); 
    if (n == -1) {
      log_info("Poll returned -1", n );
    } 
    else if ( n == 0 )
    {
      log_info("Poll timed out\n", n ); 
    }
    else
    { 
      // Check for incomming data BURP, CTRL.
      // BURP inpur
      if ( fds[BURPIX].revents & POLLIN )
      {
        fds[BURPIX].revents = 0;
        log_info("Input on event sock : %d\n", fds[BURP].fd ); 
        n = recv( fds[BURPIX].fd, buf, sizeof( buf ), 0 );
        if (n < 0)
        {
          if (errno != EWOULDBLOCK)
          {
            perror("  recv() failed");
            close_conn = TRUE;
          }
          break;
        }
        if (n == 0)
        {
          printf("BURP : Connection closed\n");
          close_conn = TRUE;
          fds[BURPIX].fd = -1;
          break;
        }
        log_info("BURP : Received %d bytes\n", n );
        parse_burp_if( buf, n );            
      }
    }
    //
    // Ctrl
    // 
    if ( fds[CLNTIX].revents & POLLIN )
    {
      fds[CLNTIX].revents =  0;
      log_info("Input on event sock : %d\n", fds[CLNTIX].fd ); 
      exit( 0 );
      if( ! client_socket )
      {
        fds[CLNTIX].revents = 0;
        new_sd = accept(fds[CLNTIX].fd, NULL, NULL);
        if( new_sd < 0 )
        {
          perror("accept()");
        } else  {
          close( fds[CLNTIX].fd ); // Close client port
          log_info("New connection on ctrl port : %d\n",new_sd );
          fds[CLNTIX].fd = new_sd;
          client_socket = 0; 
          connection_status |= CLNT;
        }
      } else {
        fds[CLNTIX].revents = 0; 
        n = recv( fds[CLNTIX].fd, buf, sizeof( buf ), 0 );
        if (n < 0)
        {
          if (errno != EWOULDBLOCK)
          {
            perror("  recv() failed");
            close_conn = TRUE;
          }
          break;
        }
        if (n == 0)
        {
          printf("  Connection closed\n");
          log_info("Creating client socket : %d\n", clnt_port );
          client_socket = create_client_socket( clnt_port );
          fds[CLNTIX].fd = client_socket;
          fds[CLNTIX].events = POLLIN;
        } else { 
          log_info("CLNT : Received %d bytes\n", n );
          parse_clnt_if( buf, n );
        }
      }
    }
    if( fds[EXCHIX].revents == POLLIN )
    {
      fds[EXCHIX].revents = 0;
      printf("Received data on the EXCH port\n");
      n = recv( fds[EXCHIX].fd, buf, sizeof( buf ), 0 );
      if (n < 0)
      {
        if (errno != EWOULDBLOCK)
        {
          perror("  recv() failed");
          close_conn = TRUE;
        }
        break;
      }
      if (n == 0)
      {
        printf("EXCH : Connection closed\n");
        close_conn = TRUE;
        break;
      }
      log_info("EXCH : Received %d bytes\n", n );
      parse_clnt_if( buf, n );

    }

    
    printf("End of loop\n");
  }
  for ( int i = 0; i < 4 ; i++)
  {
    if(fds[i].fd >= 0)
    close(fds[i].fd);
  } 
  printf("All file descriptors closed; bye\n");
  exit(EXIT_SUCCESS);
  return 0;
}
