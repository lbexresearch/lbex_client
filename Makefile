TARGET=lbex_client
CC = g++

lbex_client.cpp: lbex_client.rl
	@echo "Generate C++ file"
	ragel -G0 -o lbex_client.cpp lbex_client.rl
	@echo "Generate dot file"
	ragel -Vp -o lbex_client.dot lbex_client.rl
	dot -Tpng lbex_client.dot lbex_client.png

$(TARGET): lbex.cpp
	$(CC) lbex_client.cpp -o lbex_client
	

