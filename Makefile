CFLAGS += -Wall -Wextra -std=gnu99 -g

# if any -O... is explicitly requested, use that; otherwise, do -O3
ifeq (,$(filter -O%,$(CFLAGS) $(CXXFLAGS) $(CPPFLAGS)))
  CPPFLAGS += -O3 -ffast-math -mtune=native
endif


LDLIBS += -lm

all: compute
.PHONY: all

compute: compute.o binary_heap.o

clean:
	rm -f compute *.o *.d
.PHONY: clean
