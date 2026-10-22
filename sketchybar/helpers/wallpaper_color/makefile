all: bin/wallpaper_color

bin/wallpaper_color: wallpaper_color.swift
	mkdir -p bin
	swiftc -O wallpaper_color.swift -o bin/wallpaper_color -framework AppKit -framework CoreImage

clean:
	rm -rf bin
