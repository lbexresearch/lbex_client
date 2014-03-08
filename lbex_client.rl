/*
 * State machine definition for the beer client.
 *
 * Command interface
 *
 * The client use epoll for socket polling, see :
 * http://man7.org/tlpi/code/online/dist/altio/epoll_input.c.html
 * Changed to poll after reading this.
 * http://www.ulduzsoft.com/2014/01/select-poll-epoll-practical-difference-for-system-architects/
 * http://pic.dhe.ibm.com/infocenter/iseries/v6r1m0/index.jsp?topic=/rzab6/poll.htm
 *
 * 0. If autoconnect = true, goto 3.
 * 1. Wait for connection on the command interface.
 * 2. Verify username and password.
 * 3. Connect to exchange.
 * 4. Manage orders.
 * 4.1 
 * 
 * 7.1 Disconnect from exchange
 * 7.2 Shutdown process.
 *
 *
 *   ctrl orderReq  --> lbex_client --> order_table --> order exchange
 *   ctrl orderAck  <-- lbex_client <-- order_table <-- ack   exchange
 *   ctrl orderMat  <-- lbex_client <-- order_table <-- match exchange
                                        match_table <-|
 *   ctrl cancelOrd --> lbex_client -->            --> cancel exchange
 *   ctrl canelAcl  <-- lbex_client <-- order_table <-- cancelled exchange
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
  machine ctrl_if;

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
  }
  
  connect      = 'connect' > do_connect $anything;
  disconnect   = 'disconnect' > do_disconnect $anything;
  shutdown     = 'shutdown' % do_shutdown $anything;
  failover     = 'failover';
  node         ="[ABC]";

  main := ( connect | disconnect )* shutdown;
}%%


%%{
  machine order_mgr;

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
  request    = orderid order | cancel | quote;

  main := ( order | cancel )*;

}%%




int parse_ctrl_if( char *buffer, int length )
{
  // char buffer[] = "connectdisconnectconnectshutdown";
  char *p;
  static int cs = 1;
  char *pe, *eof;

  printf("1 parse_ctrl_if, cs = %d\n", cs); 
  
//  %% machine cmd_parser;
  %% machine ctrl_if_parser;
  %% write data;

//  %% include client_cmd;
  %% include ctrl_if;
  p = buffer;
  pe = buffer + length;
  %%{
    write init;
    write exec;
  }%%
  printf("2 parse_ctrl_if, cs = %d\n", cs);
}


int parse_order_if( int fd )
{
  char buffer[] = "B";
  char *p; 
  int  cs; 
  char *pe, *eof;

  printf("parse_order_if : \n"); 
  
  %% machine order_if_parser;
  %% write data;

  %% include order_mgr;
  p = buffer;
  pe = buffer + 33; 
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
connect_exchange( int ip, int port )
{
  int fd = 3;
  log_info("Connection to me on port %d\n", port);  

  return fd;
}



/*
 * @brief Create the control socket.
 */  
static int
create_ctrl_socket (char *port)
{
  struct addrinfo hints;
  struct addrinfo *result, *rp;
  int s, sfd;

  memset (&hints, 0, sizeof (struct addrinfo));
  hints.ai_family   = AF_UNSPEC;     /* Return IPv4 and IPv6 choices */
  hints.ai_socktype = SOCK_STREAM;   /* We want a TCP socket */
  hints.ai_flags    = AI_PASSIVE;    /* All interfaces */

  s = getaddrinfo (NULL, port, &hints, &result);
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
 * @brief Parse two streams.
 *
 * 1. Start process.
 * 2. Allocate ctrl port, if fail then exit.
 * 3. If autoconnect = 1, connect to exchange.
 * 4. .
 * 4. Connect to exchange.
 *
 * ExchangePort          CtrlPort fds
 *            0                 0   1  Listen on ctrl port
 *            0                 1   1  Connected on ctrl port
 *            1                 0   2  Connet to exch, listen ctrl.
 *            1                 1   2  Connected to both.
 */

#define MAX_BUF     1000        /* Maximum bytes fetched by a single read() */
#define TRUE 1
#define FALSE 0


main ()
{
  int cmd_fd = 1;
  int trading_fd = 2;
  int s, n;
  int efd;
  int new_sd;
  const int control_port = 0;
  const int exchange_port = 0;
  int connected_ctrl = 0;
  int connected_exch = 1;
  int    desc_ready, end_server = FALSE, compress_array = FALSE;
  int    close_conn;
  // int control_socket;
  int sfd;
  int numOpenFds;
  struct pollfd fds[2];
  
  
  char buf[1024];
  char port[] = "6500";

  printf("Starting lbex order manager\n"); 
 
  // parse_cmd_if( cmd_fd ); 

  sfd = create_ctrl_socket( port ); 
  if (sfd == -1)
  {
    log_err("Couldn't allocate ctrl port %d\n", port);
    exit( -1 );
  }

  /* Buffer where events are returned */
  fds[0].fd = sfd;
  fds[0].events = POLLIN; 
  
  fds[exchange_port].fd = sfd;
  fds[exchange_port].events = POLLIN;  

  while(1)
  {
    int n;
    printf("Waiting for control server connection\n");
    n = poll(fds, 1, 10000 );

    log_info("Event on socket : %d\n", n); 
    if (n == -1) {
      log_info("Poll returned -1", n );
    } 
    else if ( n == 0 )
    {
      log_info("Poll timed out\n", n ); 
    }
    else
    { 
      // Event on ctrl fd, eiter new connection on listen port or data.
      if ( fds[0].revents & POLLIN )
      {
        if( ! connected_ctrl )
        {
          fds[0].revents = 0;
          log_info("Input on event sock : %d\n", fds[0].fd ); 
          new_sd = accept(fds[0].fd, NULL, NULL);
          log_info("New connection on ctrl port : %d\n",new_sd );
          connected_ctrl = TRUE;
          if (new_sd < 0)
          {
            if (errno != EWOULDBLOCK)
            {
              perror("  accept() failed");
              end_server = TRUE;
            }
            break;
          } else {
            close( fds[0].fd );
            fds[0].fd = new_sd;  
          }
        } else {
          do 
          {
            n = recv( fds[0].fd, buf, sizeof( buf ), 0 );
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
              close_conn = TRUE;
              break;
            }
            log_info("Received %d bytes\n", n );
            parse_ctrl_if( buf, n );            
          } while( TRUE );
        }
      }
    }
  }
  for ( int i = 0; i < 2 ; i++)
  {
    if(fds[i].fd >= 0)
      close(fds[i].fd);
  } 
  printf("All file descriptors closed; bye\n");
  exit(EXIT_SUCCESS);
}
