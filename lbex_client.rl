#
# State machine definition for the beer client.
#
# Command interface
#
#

%%{
  machine client_cmd;

  connect="connect";
  disconnect="disconnect";
  shutdown="shutdown";
  failover="failover";
  node="[ABC]";
}%%


%%{
  machine order_mgr;

  orderid=alfanum{14};
  quantity=digit{12};
  instrument=alnum{8};
  price=digit{10};
  bid_price=price;
  ask_price=price;

  order="[BS] digit alnum digit DAY";
  cancel="C orderid orderid";
  quote="Q bid_price ask_price quantity instrument price spread";
  request=orderid order | cancel | quote;
}
