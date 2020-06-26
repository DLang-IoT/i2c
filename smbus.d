module smbus;

import std.stdio;

import core.sys.posix.sys.ioctl;
import core.sys.posix.unistd;
/** 
 * Defined in SMBus standard
 */
enum I2C_SMBUS_BLOCK_MAX = 32;

/** 
 * i2c SMBus transfer read and write markers
 */
enum I2C_SMBUS_WRITE = 0;
enum I2C_SMBUS_READ = 1;

/** 
 * SMBus transaction types
 */
enum I2C_SMBUS_QUICK = 0;
enum I2C_SMBUS_BYTE = 1;
enum I2C_SMBUS_BYTE_DATA = 2;
enum I2C_SMBUS_WORD_DATA = 3;
enum I2C_SMBUS_PROC_CALL = 4;
enum I2C_SMBUS_BLOCK_DATA = 5;
enum I2C_SMBUS_I2C_BLOCK_BROKEN = 6;
enum I2C_SMBUS_BLOCK_PROC_CALL = 7;
enum I2C_SMBUS_I2C_BLOCK_DATA = 8;

/** 
 * Combined W/R transfer
 */
enum I2C_RDWR = 0x0707; 

/** 
 * SMBus transfer
 */
enum I2C_SMBUS = 0x0720; 

/** 
 * Slave address
 */
enum I2C_SLAVE = 0x0703;

/** 
 * Slave address even if it is used by a driver
 */
enum I2C_SLAVE_FORCE = 0x0706;

/** 
 * Data for SMBus messages
 */
union i2c_smbus_data {
	ubyte byte_b;
	ushort word_w;
	ubyte[I2C_SMBUS_BLOCK_MAX+2] block; /* block[0] is used for length 
		and another one for user-space compatibility*/
}

/** 
 * Structure used in the I2C_SMBUS ioctl call
 */
struct i2c_smbus_ioctl_data {
	ubyte read_write;
	ubyte command;
	uint size;
	i2c_smbus_data* data;
}

/** 
 * This function communicates with the i2c SMBus through an ioctl call
 * Params:
 *   fd = file descriptor of the i2c SMBus
 *   read_write = flag for write or read to/from the i2c SMBus
 *   command = ??
 *   size = number of bytes to be written or read to/from the i2c SMBus
 *   data = buffer for the data to be written or read to/from the i2c SMBus
 * Returns: 
 */
int i2c_smbus_access(int fd, char read_write, ubyte command, int size, i2c_smbus_data* data)
{
	i2c_smbus_ioctl_data args;
	int rc;


	args.read_write = cast(ubyte) read_write;
	args.command = command;
	args.size = size;
	args.data = data;

	rc = ioctl(fd, I2C_SMBUS, &args);
	
	if (rc == -1) {
		// todo error
	}
	return rc;
}

/** 
 * 
 * Params:
 *   file = file descriptor of the i2c SMBus
 *   value = value
 * Returns: 
 */
int i2c_smbus_write_quick(int file, ubyte value)
{
	return i2c_smbus_access(file, value, 0, I2C_SMBUS_QUICK, null);
}

/** 
 * 
 * Params:
 *   file = file descriptor of the i2c SMBus to read from
 * Returns: 
 *   ubyte that represents the byte read from the i2c SMBus
 */
int i2c_smbus_read_byte(int file)
{
	i2c_smbus_data data;
	int rc;

	rc = i2c_smbus_access(file, I2C_SMBUS_READ, 0, I2C_SMBUS_BYTE, &data);
	if (rc < 0)
		return rc;
	return 0x0FF & data.byte_b;
}

int i2c_set_slave2(int file, ubyte addr)
{
	int res = ioctl(file, I2C_SLAVE_FORCE, addr);
	writeln(res);
    return 0;
}


int i2c_set_slave(int file, ubyte addr)
{
	int res = ioctl(file, I2C_SLAVE_FORCE, addr);
    return 0;
}

/** 
 * 
 * Params:
 *   file = file descriptor of the i2c SMBus to read from
 *   value = value of the byte to be written
 * Returns: integer representing the number of written bytes
 * 	(should return 1)
 */
int i2c_smbus_write_byte(int file, ubyte value)
{
	return i2c_smbus_access(file, I2C_SMBUS_WRITE, value, I2C_SMBUS_BYTE, null);
}

int i2c_smbus_read_byte_data(int file, ubyte command)
{
	i2c_smbus_data data;
	int rc;

	rc = i2c_smbus_access(file, I2C_SMBUS_READ, command, I2C_SMBUS_BYTE_DATA, &data);
	if (rc < 0)
		return rc;

	return 0x0FF & data.byte_b;
}

int i2c_smbus_write_byte_data(int file, ubyte command, ubyte value)
{
	i2c_smbus_data data;
	data.byte_b = value;
	return i2c_smbus_access(file, I2C_SMBUS_WRITE, command, I2C_SMBUS_BYTE_DATA, &data);
}

int i2c_smbus_read_word_data(int file, ubyte command)
{
	i2c_smbus_data data;
	int rc;

	rc = i2c_smbus_access(file, I2C_SMBUS_READ, command, I2C_SMBUS_WORD_DATA, &data);
	if (rc < 0)
		return rc;

	return 0x0FFFF & data.word_w;
}

int i2c_smbus_write_word_data(int file, ubyte command, ushort value)
{
	i2c_smbus_data data;
	data.word_w = value;
	return i2c_smbus_access(file, I2C_SMBUS_WRITE, command, I2C_SMBUS_WORD_DATA, &data);
}

int i2c_smbus_process_call(int file, ubyte command, ushort value)
{
	i2c_smbus_data data;
	data.word_w = value;
	if (i2c_smbus_access(file, I2C_SMBUS_WRITE, command, I2C_SMBUS_BLOCK_PROC_CALL, &data))
		return -1;
	return 0x0FFFF & data.word_w;
}

int i2c_smbus_read_block_data(int file, ubyte command, ubyte[] values)
{
	i2c_smbus_data data;
	int i, rc;

	rc = i2c_smbus_access(file, I2C_SMBUS_READ, command, I2C_SMBUS_BLOCK_DATA, &data);
	if (rc < 0)
		return rc;

	for (i = 1; i <= data.block[0]; i++)
		values[i-1] = data.block[i];
	return data.block[0]; 
}

int i2c_smbus_write_block_data(int file, ubyte command, ubyte length,const ubyte[] values)
{
	i2c_smbus_data data;
	int i;
	if (length > I2C_SMBUS_BLOCK_MAX)
		length = I2C_SMBUS_BLOCK_MAX;
	for (i = 1; i <= length; i++)
		data.block[i] = values[i-1];
	data.block[0] = length;
	return i2c_smbus_access(file, I2C_SMBUS_WRITE, command, I2C_SMBUS_BLOCK_DATA, &data);
}

/** 
 * This function reads a block of data from the i2c SMBus 
 * Params:
 *   file = file descriptor to read from
 *   command = read/write marker
 *   length = number of bytes to be read
 *   values = where to store the read data
 * Returns:
 *   integer representing the number of bytes read
 */
int i2c_smbus_read_i2c_block_data(int file, ubyte command, ubyte length, ubyte[] values)
{
	i2c_smbus_data data;
	int i, rc;

	if (length > I2C_SMBUS_BLOCK_MAX)
		length = I2C_SMBUS_BLOCK_MAX;
	data.block[0] = length;

	rc = i2c_smbus_access(file, I2C_SMBUS_READ, command, length == 32 ?
		I2C_SMBUS_I2C_BLOCK_BROKEN : I2C_SMBUS_I2C_BLOCK_DATA, &data);
	if (rc < 0)
		return rc;
	
	for (i = 1; i <= data.block[0]; i++)
		values[i-1] = data.block[i];
	return data.block[0];
}

/** 
 * This function writes a block of data to the i2c SMBus
 * Params:
 *   file = file descriptor to write to
 *   command = read/write marker
 *   length = number of bytes to write
 *   values = the buffer to write from
 * Returns: 
 * 	 integer representing the number of bytes written
 */
int i2c_smbus_write_i2c_block_data(int file, ubyte command, ubyte length, const ubyte[] values)
{
	i2c_smbus_data data;
	int i;

	if (length > I2C_SMBUS_BLOCK_MAX)
		length = I2C_SMBUS_BLOCK_MAX;

	for (i = 1; i <= length; i++)
		data.block[i] = values[i-1];
	data.block[0] = length;
	return i2c_smbus_access(file, I2C_SMBUS_WRITE, command, I2C_SMBUS_I2C_BLOCK_DATA, &data);
}

int i2c_smbus_block_process_call(int file, ubyte command, ubyte length, ubyte[] values)
{
	i2c_smbus_data data;
	int i, rc;

	if (length > I2C_SMBUS_BLOCK_MAX)
		length = I2C_SMBUS_BLOCK_MAX;
	for (i = 1; i < length; i++)
		data.block[i] = values[i-1];
	data.block[0] = length;

	rc = i2c_smbus_access(file, I2C_SMBUS_WRITE, command, I2C_SMBUS_BLOCK_PROC_CALL, &data);
	if (rc < 0)
		return rc;
	
	for (i = 1; i <= data.block[0]; i++)
		values[i-1] = data.block[i];
	return data.block[0];
}