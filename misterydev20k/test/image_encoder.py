#!/usr/bin/python3
import png, sys

print("Image encoder")

# simple rle encoding. Encodes to 36 bit RGBL where L is the
# 12 bit run length -1

# reduce colors if needed:
# convert mistle.png -dither none -colors 500 -depth 8 -alpha on mistle.png

RUN_BITS = 8
COLOR_BITS = 10

def encode(inname, cmapname, outname):
    print("Encoding", inname, "into", cmapname, outname)

    try:
        reader = png.Reader(inname)
        w,h,pixels,metadata = reader.read_flat()
        pixel_byte_width = 4 if metadata['alpha'] else 3
    except Exception as e:
        print(str(e))
        sys.exit(-1)

    print("Image size is", metadata["size"])
        
    if  metadata["bitdepth"] != 8:
        print("Metadata:", metadata)
        print("24 bit RGBA expected")
        sys.exit(-1)    

    # export color map
    with open(cmapname, "w") as outfile:
        colors = [ ]
        for i in range(metadata["size"][0] * metadata["size"][1]):
            if "palette" in metadata:
                rgb = metadata["palette"][pixels[i]][0:3]
            else:            
                if metadata["alpha"]: rgb = pixels[4*i:4*i+3]
                else:                 rgb = pixels[3*i:3*i+3]

            if not rgb in colors:
                colors.append(rgb)

        print("Number of colors:", len(colors))
        for rgb in colors:
            outfile.write("{:02X}{:02X}{:02X}\n".format(rgb[0],rgb[1],rgb[2]))
                
    # build hex encoded rle
    elen = 0    
    with open(outname, "w") as outfile:
        # do simple rle encoding
        lastpix = None
        run = 0

        for i in range(metadata["size"][0] * metadata["size"][1]):
            if "palette" in metadata:                
                rgb = metadata["palette"][pixels[i]][0:3]
            else:            
                if metadata["alpha"]: rgb = pixels[4*i:4*i+3]
                else:                 rgb = pixels[3*i:3*i+3]

            # write run if either the color has changed or the current
            # runs length has exceeded the max length
            if rgb != lastpix or run == (1<<RUN_BITS):
                if run:
                    outfile.write(("{:0"+str(RUN_BITS//4)+"X}\n").format(run-1))

                # write 24 bit color
                outfile.write("{:03X}".format(colors.index(rgb)))
                elen += 1
                lastpix = rgb
                run = 1
            else:
                run += 1
        
        outfile.write(("{:0"+str(RUN_BITS//4)+"X}\n").format(run))

        print("Encoded length:", elen*((COLOR_BITS+RUN_BITS)/8), "("+str(elen)+"*"+str(COLOR_BITS+RUN_BITS)+" bits)")

encode("mistle.png", "mistle_cmap.mem", "mistle.mem")
