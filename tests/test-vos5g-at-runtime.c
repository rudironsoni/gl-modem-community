// SPDX-License-Identifier: GPL-3.0-only

#include <assert.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	static const char response[] =
		"\r\n+CGPADDR: 1,192.0.2.42,32.1.13.184.0.0.0.1\r\nOK\r\n";
	static const char expected[] =
		"\r\n+CGPADDR: 1,\"192.0.2.42\",\"32.1.13.184.0.0.0.1\"\r\nOK\r\n";
	char buffer[256] = { 0 };
	int fd;
	ssize_t length;

	assert(argc == 2);
	fd = open(argv[1], O_RDWR | O_TRUNC);
	assert(fd >= 0);
	assert(write(fd, response, sizeof(response) - 1) == sizeof(response) - 1);
	assert(lseek(fd, 0, SEEK_SET) == 0);
	length = read(fd, buffer, sizeof(buffer));
	assert(length == sizeof(expected) - 1);
	assert(memcmp(buffer, expected, sizeof(expected) - 1) == 0);
	close(fd);
	return 0;
}
