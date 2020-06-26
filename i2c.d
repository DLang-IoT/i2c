module i2c;

import smbus;
import std.stdio;
import std.string;
import std.format;
import std.process;
import std.array;
import std.conv;
import core.sys.posix.unistd;
import core.sys.posix.sys.ioctl;
import std.algorithm;

File file;
int i2c_buses_index = 0;
int[] i2c_buses;
int[] i2c_buses_boards;
ubyte[] i2c_buses_addresses;

enum int RASPBERRY = 0;
enum int BEAGLE1 = 1;
enum int BEAGLE2 = 2;


int init(ubyte addr, int bus = -1)
{
    if (bus == -1)
        bus = autodetect_board(addr);
    else {
        string filepath = format!"%s%s"("/dev/i2c-", to!string(bus));
        File check_file = File(filepath, "rw");

        if (check_file.fileno < 0) {
            throw new Exception("Unable to make the connection to the I2C bus. Did you enter the rigth bus and address?\n");
        }

        int ss = i2c_set_slave(check_file.fileno, addr);
        int res = i2c_smbus_read_byte(check_file.fileno);

        if (res < 0) {
            throw new Exception("Unable to establish the I2C connection.\n");
        } else {
            i2c_buses.length += 1;
            i2c_buses_addresses.length += 1;
            i2c_buses_boards.length += 1;
            i2c_buses[i2c_buses_index] = bus;
            i2c_buses_addresses[i2c_buses_index] = addr;
            i2c_buses_boards[i2c_buses_index] = -1;
            i2c_buses_index++;
        }
    }
    return bus;
}

int autodetect_board(ubyte addr)
{
    File cpuinfo;
    try {
        cpuinfo = File("/proc/cpuinfo", "r");
    } catch (std.exception.ErrnoException e) {
		throw new Exception("Unable to open /proc/cpuinfo");
	}

    char[] line;
    while (!cpuinfo.eof()) {
        line = cast(char[]) cpuinfo.readln();
        if (line.canFind("Hardware")) 
            break;
    }
    if (line.canFind("BCM283") || line.canFind("BCM271")) {
        // check for default bus - 1
        File check_file = File("/dev/i2c-1", "rw");

        if (check_file.fileno < 0)
        {
            throw new Exception("Unable to make the connection to the I2C bus. Do you have a Raspberry Pi?\n");
        }

        i2c_set_slave(check_file.fileno, addr);
        int res = i2c_smbus_read_byte(check_file.fileno);

        if (res < 0)
        {
            throw new Exception("Unable to establish the I2C connection.\n");
        } else { 
            i2c_buses.length += 1;
            i2c_buses_addresses.length += 1;
            i2c_buses_boards.length += 1;
            i2c_buses[i2c_buses_index] = 1;
            i2c_buses_addresses[i2c_buses_index] = addr;
            i2c_buses_boards[i2c_buses_index] = RASPBERRY;
            i2c_buses_index++;
            check_file.close();
            return 1;
        }
    } else if (line.canFind("AM33XX")) {
        // check for default bus - 2
        bool bus_1 = false, bus_2 = false, double_try = false;
        if (i2c_buses_index)
            for (int bus_index = 0; bus_index < i2c_buses_index; bus_index++) {
                if (i2c_buses[bus_index] == 2 && i2c_buses_addresses[bus_index] == addr)
                    bus_2 = true;
                if (i2c_buses[bus_index] == 1 && i2c_buses_addresses[bus_index] == addr)
                    bus_1 = true;
                if (bus_1 && bus_2)
                    break;
            }
        int check_bus = 0;
        if (bus_2 && !bus_1) {
            // bus 1
            check_bus = 1;
        } else if (bus_1 && !bus_2) {
            // bus 2
            check_bus = 2;
        } else if (!bus_1 && !bus_2) {
            check_bus = 2;
            double_try = true;
        } else {
            throw new Exception("There are no free buses for your device!\n");
            return -1;
        }

        while(check_bus > 0) {
            writeln("incercam cu ", check_bus);
            string filepath = format!"%s%s"("/dev/i2c-", to!string(check_bus));
            File check_file = File(filepath, "rw");

            if (check_file.fileno < 0) {
                if (check_bus == 1) {
                    throw new Exception("Unable to make the connection to the I2C bus. Do you have a BeagleBone Black board?\n");
                }
            }

            int ss = i2c_set_slave(check_file.fileno, addr);
            int res = i2c_smbus_read_byte(check_file.fileno);

            if (res < 0) {
                if (check_bus == 1) {
                    throw new Exception("Unable to establish the I2C connection.\n");
                }
            } else {
                i2c_buses.length += 1;
                i2c_buses_addresses.length += 1;
                i2c_buses_boards.length += 1;
                i2c_buses[i2c_buses_index] = check_bus;
                i2c_buses_addresses[i2c_buses_index] = addr;
                if (check_bus == 1)
                    i2c_buses_boards[i2c_buses_index] = BEAGLE1;
                else if (check_bus == 2)
                    i2c_buses_boards[i2c_buses_index] = BEAGLE2;
                i2c_buses_index++;
                check_file.close();

                return check_bus;
            }
            check_bus--;
        }
    }
    cpuinfo.close(); 
    return 1; 
    
}

int open_adapter(int bus)
{
    if (bus == -1 && i2c_buses_index > 0) {
        bus = i2c_buses[i2c_buses_index - 1];
    }
    string filepath = format!"%s%s"("/dev/i2c-", to!string(bus));
    file = File(filepath, "rw");

    if (file.fileno < 0)
    {
        throw new Exception("Unable to open i2c bus");
    }

    return file.fileno;
}


int set_slave(int fd, ubyte addr)
{
    return i2c_set_slave(fd, addr);
}

int write_bytes(int fd, ubyte[] bytes, ubyte length)
{
    int rc = 0;
    const ubyte[] bytes_to_send = bytes[1..$];
    ubyte new_length = cast(ubyte) (length - 1);

    rc = i2c_smbus_write_i2c_block_data(fd, bytes[0], new_length, bytes_to_send);
    if (rc < 0) {
       throw new Exception("Unable to write data");
    }

    return rc;
}

int read_byte(int fd)
{
    int rc = i2c_smbus_read_byte(fd);
    if (rc < 0) {
        return -1;
    }
    return rc;
}

int write_byte(int fd, ubyte[] bytes)
{
    int rc;

    rc = i2c_smbus_write_byte(fd, bytes[0]);
    if (rc < 0) {
        throw new Exception("Unable to write data");
    }

    return rc;
}

int read_bytes(int fd, ubyte[] buffer, uint length)
{
    int rc = 0;
    int i, data;

    rc = core.sys.posix.unistd.read(fd, cast(void*) buffer, length);
    return rc;
}