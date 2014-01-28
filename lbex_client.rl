#
# State machine definition for the beer client.
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

  order="[BS] digit alnum digit DAY";
  cancel="C orderid orderid";
  quote="[BS] quantity instrument price";
  request=orderid order | cancel | quote;
}
