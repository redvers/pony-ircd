PROG = pony-ircd

all:		$(PROG)

$(PROG):	main.pony IrcClientSession.pony
	ponyc -d -b $(PROG) .

run:		$(PROG)
	./$(PROG)

clean:
	rm -f *.o $(PROG)
