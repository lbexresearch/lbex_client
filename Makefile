TARGET = lbex_client lbex_gw
CC = g++
CFLAGS	= -lrt

all: lbex_client lbex_gw

debug: CC += -DDEBUG -g
debug: $(TARGET)

lbex_client: lbex_client.cpp
	$(CC) $(CFLAGS) lbex_client.cpp -o lbex_client

lbex_gw: lbex_gw.cpp
	$(CC) $(CFLAGS) lbex_gw.cpp -o lbex_gw


lbex_client.cpp: lbex_client.rl
	@echo "Generate C++ file"
	ragel -G0 -o lbex_client.cpp lbex_client.rl
	@echo "Generate dot file"
	ragel -Vp -o lbex_client.dot lbex_client.rl
	dot -Tpng lbex_client.dot -o lbex_client.png


lbex_client.cpp: lbex_gw.rl
	@echo "Generate C++ file"
	ragel -G0 -o lbex_gw.cpp lbex_gw.rl
	@echo "Generate dot file"
	ragel -Vp -o lbex_gw.dot lbex_gw.rl
	dot -Tpng lbex_gw.dot -o lbex_gw.png
