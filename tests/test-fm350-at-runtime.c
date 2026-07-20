// SPDX-License-Identifier: GPL-3.0-only

#include <assert.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	static const char command[] = "AT+CGACT=1,5\r";
	static const char expected_command[] = "AT+CGACT=1,1\r";
	static const char expected_response[] = "\r\nOK\r\n";
	char buffer[32] = { 0 };
	int fd;
	ssize_t length;

	assert(argc == 2);
	fd = open(argv[1], O_RDWR | O_TRUNC);
	assert(fd >= 0);
	assert(write(fd, command, sizeof(command) - 1) == sizeof(command) - 1);
	assert(read(fd, buffer, 2) == 2);
	assert(read(fd, buffer + 2, sizeof(buffer) - 2) ==
	       sizeof(expected_response) - 3);
	assert(memcmp(buffer, expected_response, sizeof(expected_response) - 1) == 0);
	assert(lseek(fd, 0, SEEK_SET) == 0);
	memset(buffer, 0, sizeof(buffer));
	length = read(fd, buffer, sizeof(buffer));
	assert(length == sizeof(expected_command) - 1);
	assert(memcmp(buffer, expected_command, sizeof(expected_command) - 1) == 0);
	close(fd);

	return 0;
}
