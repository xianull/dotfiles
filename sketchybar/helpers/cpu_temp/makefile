all: bin/cpu_temp

bin/cpu_temp: cpu_temp.swift
	mkdir -p bin
	swiftc -O cpu_temp.swift -o bin/cpu_temp -framework IOKit -framework Foundation

clean:
	rm -rf bin
