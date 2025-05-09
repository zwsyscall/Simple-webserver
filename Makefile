all: server

server: server.o
	ld -m elf_x86_64 -o server server.o

server.o: server.asm
	nasm -f elf64 server.asm -o server.o

run: server
	./server

clean:
	rm -f server.o server

