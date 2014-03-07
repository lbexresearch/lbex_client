/*
 * State machine definition for the beer client.
 *
 * Command interface
 *
 * The client use epoll for socket polling, see :
 * http://man7.org/tlpi/code/online/dist/altio/epoll_input.c.html
 *
 * 1. Wait for connection on the command interface.
 * 2. Verify username and password.
 * 3. Connect to exchange.
 * 4. Manage orders.
 * 4.1 
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
#include <sys/epoll.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>
#include <errno.h>

#include "logger.h"


#define MAXEVENTS 64

%%{
  machine client_cmd;

  action do_connect {
    printf("Connect\n");
  }

  action do_disconnect {
    printf("Disconnect\n");
  }

  action do_shutdown {
    printf("Shutdown\n");
  }
  
  connect      ="connect" > do_connect;
  disconnect   ="disconnect" > do_disconnect;
  shutdown     ="shutdown" % do_shutdown;
  failover     ="failover";
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




int parse_cmd_if( int fd )
{
  char buffer[] = "connectdisconnectconnectshutdown";
  char *p;
  int cs;
  char *pe, *eof;

  printf("parse_cmd_if : \n"); 
  
//  %% machine cmd_parser;
  %% machine order_mgr_parser;
  %% write data;

//  %% include client_cmd;
  %% include order_mgr;
  p = buffer;
  pe = buffer + 33;
  %%{
    write init;
    write exec;
  }%%
}


int parse_order_if( int fd )
{
  char buffer[] = "B";
  char *p; 
  int  cs; 
  char *pe, *eof;

  printf("parse_cmd_if : \n"); 
  
  %% machine order_mgr_parser;
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
 * 2. Listen for control port connection.
 * 3. When control process connects.
 * 4. Connect to exchange.
 */

#define MAX_BUF     1000        /* Maximum bytes fetched by a single read() */

main ()
{
  int cmd_fd = 1;
  int trading_fd = 2;
  int s, n;
  int efd;
  // int control_socket;
  int sfd;
  int numOpenFds;
  struct epoll_event ev;
  struct epoll_event evlist[MAXEVENTS];
  char buf[1024];
  
  
  char port[] = "6500";
 
  struct epoll_event event;
  struct epoll_event *events; 

  printf("Starting lbex order manager\n"); 
 
  parse_cmd_if( cmd_fd ); 

  sfd = create_ctrl_socket( port ); 
  if (sfd == -1)
    abort ();

  make_socket_non_blocking (sfd);
  if (s == -1)
    abort ();

  s = listen (sfd, SOMAXCONN);
  if (s == -1)
    {
      perror ("listen");
      abort ();
    }  


  efd = epoll_create1 (0);
  if (efd == -1)
    {
      perror ("epoll_create");
      abort ();
    }

  event.data.fd = sfd;
  event.events = EPOLLIN | EPOLLET;
  s = epoll_ctl (efd, EPOLL_CTL_ADD, sfd, &event);
  if (s == -1)
    {
      perror ("epoll_ctl");
      abort ();
    }

  /* Buffer where events are returned */
  events = ( epoll_event* )calloc (MAXEVENTS, sizeof event);
 


  while(1)
  {
    int n;

    printf("Waiting for control server connection\n");
    n = epoll_wait (efd, events, MAXEVENTS, -1);
  

    log_info("Connection on port : %d\n", n); 
    if (n == -1) {
      if (errno == EINTR)
        continue;               /* Restart if interrupted by signal */
      else
        perror("epoll_wait");
        exit(-1);
    } 
    
    printf("Ready: %d\n", n);

    /* Deal with returned list of events */

    for (int j = 0; j < n; j++) {
      printf("  fd=%d; events: %s%s%s\n", evlist[j].data.fd,
      (evlist[j].events & EPOLLIN)  ? "EPOLLIN "  : "",
      (evlist[j].events & EPOLLHUP) ? "EPOLLHUP " : "",
      (evlist[j].events & EPOLLERR) ? "EPOLLERR " : "");

      if (evlist[j].events & EPOLLIN) {
        s = read(evlist[j].data.fd, buf, MAX_BUF);
        if (s == -1)
        printf("read");
        printf("    read %d bytes: %.*s\n", s, s, buf);

      } else if (evlist[j].events & (EPOLLHUP | EPOLLERR)) {

        /* After the epoll_wait(), EPOLLIN and EPOLLHUP may both have
           been set. But we'll only get here, and thus close the file
           descriptor, if EPOLLIN was not set. This ensures that all
           outstanding input (possibly more than MAX_BUF bytes) is
           consumed (by further loop iterations) before the file
           descriptor is closed. */

           printf("    closing fd %d\n", evlist[j].data.fd);
           if (close(evlist[j].data.fd) == -1)
             printf("close");
             numOpenFds--;
           }
     }
    }
    printf("All file descriptors closed; bye\n");
    exit(EXIT_SUCCESS);
    
    log_info("Connection on port : %d\n", n);
     
}

