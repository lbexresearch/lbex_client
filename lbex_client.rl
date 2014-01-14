#
# State machine definition for the beer client.
#

%%{
  machine client_cmd;

  connect="connect";
  disconnect="disconnect";
  shutdown="shutdown";

  quantity=digit{12};
  instrument=alnum{8};
  price=digit{10};

  order="[BS] digit alnum digit DAY";

}
