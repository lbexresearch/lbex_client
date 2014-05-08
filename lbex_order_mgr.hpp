/*
 * @brief LBEX client order management.
 *
 * 1.   Add new order
 * 1.1  New Order accepted.
 * 1.2  New Order Rejected
 *
 * 2    Cancel Order
 *
 * 3.   Partial fill on order.
 *
 * 4.   Full fill on order.
 *
 * 5.   Unsolicited cancel, e.g IOC order.
 * 5.1  Uncolicited cancel of full order.
 * 5.2  Unsolicited cancel of partial filled order.
 */
#include <string>
#include <map>
#include <iostream>
#include <fstream>
#include <stdint.h>
#include <vector>

using namespace std;

enum Side 
{ 
  B = 0,
  S = 1
};

class Instrument {
  uint32_t instrument_id;
  char     symbol[8];
};

class InstrumentTable {
  // Quote instrumet[MAX_INSTRUMENTS];
  
  public:
    InstrumentTable( const string file_n );
    int Init( FILE fh ); 
    
};

InstrumentTable::InstrumentTable( const string file_n )
{
  string    symbolname;
  string    line;
  int       lot_size;

  std::cout << "Init InstrumentTable from file : " << file_n << std::endl;

  ifstream instrument_file( file_n.c_str(), std::ifstream::in );

  while(!instrument_file.eof()){
    
    //read data from file
    line.clear();
    std::getline( instrument_file, line );
    // sscanf(line," %s %d", &symbolname, &lot_size );
    std::cout << "Line : " << line << std::endl; 
  }
  
  instrument_file.close();
};

class Order {
    static uint32_t  unique_id ;
    const uint32_t   id;
    Instrument       instrument;
    Side             side;
    int              qty;
    int              price;
  public:
    Order( Instrument i, 
           Side       s,
           int        q,
           int        p   
          ) : id ( unique_id++ )
    {
      instrument = i;
      side       = s;
      qty        = q;
      price      = p;
    }

};

class Quote {
  Order buy;
  Order sell;
  uint32_t matched_buy;
  uint32_t total_price__buy;
  uint32_t matched_sell;
  uint32_t total_price_sell;

};

class OrderBook {
  Instrument  instrument;
  vector<Order> buyOrders;
  vector<Order> sellOrders;
};
  

template<class Orderbook>
void add( uint32_t qty, uint32_t price )
{
  static uint32_t open_value =+ qty * price;
  static uint32_t open_qty   =+ qty;
};

template<typename T>
T cancel( uint32_t qty, uint32_t price )
{
  
  static uint32_t open_value = 0;
  static uint32_t open_qty   = 0;

  open_value =+ qty * price;
  open_qty   =+ qty;
};



template<typename T> 
T fill( uint32_t qty, uint32_t price )
{
  T::cancel( qty, price );
  uint32_t realised_value =+ qty * price;
  uint32_t realised_qty   =+ qty;
}; 
