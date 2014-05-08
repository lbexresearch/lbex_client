TARGET = lbex_gw lbex_client
CC = g++
CFLAGS	= -lrt

all: $(TARGET)

debug: CC += -DDEBUG -g
debug: $(TARGET)

lbex_client: lbex_client.cpp lbex_order_mgr.o
	$(CC) $(CFLAGS) lbex_client.cpp -o lbex_client

lbex_gw: lbex_gw.cpp
	$(CC) $(CFLAGS) lbex_gw.cpp -o lbex_gw


lbex_order_mgr.o: lbex_order_mgr.hpp
	$(CC) lbex_order_mgr.hpp -o lbex_order_mgr.o

lbex_client.cpp: lbex_client.rl
	@echo "Generate C++ file"
	ragel -G0 -o lbex_client.cpp lbex_client.rl
	@echo "Generate dot file"
	ragel -Vp -o lbex_client.dot lbex_client.rl
	dot -Tpng lbex_client.dot -o lbex_client.png


lbex_gw.cpp: lbex_gw.rl
	@echo "Generate C++ file"
	ragel -G0 -o lbex_gw.cpp lbex_gw.rl
	@echo "Generate dot file"
	ragel -Vp -o lbex_gw.dot lbex_gw.rl
	dot -Tpng lbex_gw.dot -o lbex_gw.png
