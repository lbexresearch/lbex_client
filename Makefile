TARGET = lbex_client
CC = g++
CFLAGS	= -lrt

$(TARGET): lbex_client.cpp
	$(CC) $(CFLAGS) lbex_client.cpp -o lbex_client

lbex_client.cpp: lbex_client.rl
	@echo "Generate C++ file"
	ragel -G0 -o lbex_client.cpp lbex_client.rl
	@echo "Generate dot file"
	ragel -Vp -o lbex_client.dot lbex_client.rl
	dot -Tpng lbex_client.dot -o lbex_client.png
