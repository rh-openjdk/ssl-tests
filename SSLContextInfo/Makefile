SRC_DIR=src
CLASSES_DIR=classes

JAVA=java
JAVAC=javac

MAIN_CLASS = SSLContextInfo

.PHONY: clean build run

all: run

clean:
	rm -rf $(CLASSES_DIR)

build: $(CLASSES_DIR)

run: $(CLASSES_DIR)
	$(JAVA) -cp $< $(MAIN_CLASS)

$(CLASSES_DIR): $(SRC_DIR)
	mkdir $@
	$(JAVAC) -d $@ $</*
