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


template<class orderbook>
void add( uint32_t qty, uint32_t price )
{
  open_value += qty * price;
  open_qty   += qty;
}

void remove( uint32_t qty, uint32_t price )
{
  open_value += qty * price;
  open_qty   += qty;
}


template fill( uint32_t qty, uint32_t price )
{
  remove( qty, price );
  realised_value += qty * price;
  realised_qty   += qty;
} 
