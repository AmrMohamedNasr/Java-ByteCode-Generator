all: java.y java.l main.cpp java.h label.h label.cpp
	bison -d java.y
	flex java.l
	g++ label.cpp java.tab.c lex.yy.c main.cpp -lfl -o java
	rm ./java.tab.c
	rm ./lex.yy.c
	rm ./java.tab.h
	mkdir ./build -p
	mv java ./build/java
clean:
	rm ./build -r