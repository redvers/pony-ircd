PROG = pony-ircd

all:		$(PROG)

$(PROG):	main.pony IrcClientSession.pony
	corral run -- ponyc -d -Dopenssl_1.1.x -b $(PROG) .

run:		$(PROG)
	./$(PROG)

clean:
	rm -f *.o $(PROG)
