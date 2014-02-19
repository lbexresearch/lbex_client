/*
 * State machine definition for the beer client.
 *
 * Command interface
 *
 */

#include <stdio.h>

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

  order      = "[BS] digit alnum digit DAY" > enter_order;
  cancel     = "C orderid orderid" > cancel_order;
  quote      = "Q bid_price ask_price quantity instrument price spread" > enter_quote;
  request    = orderid order | cancel | quote;
}%%




int parse_cmd_if( int fd )
{
  char buffer[] = "connectdisconnectconnectshutdown";
  char *p;
  int cs;
  char *pe, *eof;

  printf("parse_cmd_if : \n"); 
  
  %% machine cmd_parser;
  %% write data;

  %% include client_cmd;
  p = buffer;
  pe = buffer + 33;
  %%{
    # main := ( connect | disconnect ) shutdown;
    write init;
    write exec;
  }%%
}
  


/*
 * @brief Parse two streams.
 */

main ()
{
  int cmd_fd = 1;
  int trading_fd = 2;

  printf("Starting lbex order manager\n"); 
 
  parse_cmd_if( cmd_fd ); 

}

