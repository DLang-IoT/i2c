module wire;

import std.stdio;
import std.format;
import std.string;
import std.conv;
import std.file;

import core.sys.posix.sys.ioctl;
import core.thread;
import core.stdc.errno;
import core.sys.posix.unistd;

import i2c;

enum MAX_I2C_PINS = 10;
enum BUFFER_LENGTH = 32;


enum int BEAGLE1 = 1;
enum int BEAGLE2 = 2;

public class Wire {
public:

	this(ubyte addr, int bus = -1)
	{
		this.bus = bus;
		this.con_addr = addr;
	}

	void releaseI2CId (int id)
	{
		fd = -1;
	}


	void begin()
	{
		bus = i2c.init(con_addr, bus);
		i2c_id = i2c.open_adapter(bus);
		if (i2c_id < 0) {
			return;
		}
	}

	
	void beginTransmission(uint address)
	{
		if (i2c_id < 0)
			return;
		i2c.set_slave(cast(uint) i2c_id, cast(ubyte) address);
		txAddress = cast(ubyte) address;
		txBufferLength = 0;
	}

	void beginTransmission(int address)
	{
		beginTransmission(cast(uint) address);
	}

	ubyte requestFrom(ubyte address, ubyte quantity, bool sendStop)
	{
		int rc;
		if (quantity > BUFFER_LENGTH)
			quantity = BUFFER_LENGTH;

		i2c.set_slave(i2c_id, address);

		if (i2c.read_bytes(i2c_id, cast(ubyte[]) rxBuffer, cast(uint) quantity) < 0) {
			return 0;
		}
		
		rxBufferIndex = 0;
		rxBufferLength = quantity;

		return quantity;
	}

	ubyte requestFrom(ubyte address, ubyte quantity)
	{
		return requestFrom(address, quantity, cast(bool) true);
	}

	ubyte requestFrom(uint address, uint quantity)
	{
		return requestFrom(cast(ubyte) address, cast(ubyte) quantity, cast(bool) true);
	}

	ubyte requestFrom(uint address, uint quantity, uint sendStop)
	{
		return requestFrom(cast(ubyte) address, cast(ubyte) quantity, cast(bool) sendStop);
	}

	auto writeData(byte data)
	{
		if (txBufferLength >= BUFFER_LENGTH) 
			return 0;
		txBuffer[txBufferLength++] = data;
		return 1;
	}

	int readData()
	{
		if (rxBufferIndex < rxBufferLength) {
			return rxBuffer[rxBufferIndex++];
		}
		return -1;
	}

	ubyte endTransmission(bool sendStop)
	{
		uint err;
		if (sendStop == true)
		{
			if (txBufferLength > 1) {
				err = i2c.write_bytes(i2c_id, txBuffer, txBufferLength);
			}
			else if (txBufferLength == 1) {
				err = i2c.write_byte(i2c_id, txBuffer);
			}
			else {
				err = i2c.read_byte(i2c_id);
			}

			txBufferLength = 0;
			if (err < 0)
				return 2;
			return 0;
		} else {
			return 0;
		}
	}

	ubyte endTransmission()
	{
		return endTransmission(true);
	}

private:
	uint fd;

	uint i2c_id;

	int bus;
	ubyte con_addr;

	ubyte adapter_nr;

	ubyte[BUFFER_LENGTH] rxBuffer;
	ubyte rxBufferIndex;
	ubyte rxBufferLength;

	ubyte[BUFFER_LENGTH] txBuffer;
	ubyte txAddress;
	ubyte txBufferLength;

	ubyte[BUFFER_LENGTH] srvBuffer;
	ubyte srvBufferIndex;
	ubyte srvBufferLength;	
}
