// SPDX-License-Identifier: GPL-3.0-only

#include <stddef.h>
#include <string.h>

#ifndef UNIT_TEST
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>
#endif

int fm350_rewrite_tx(unsigned char *buffer, size_t length)
{
	static const unsigned char command[] = "AT+CFUN=0";
	size_t index;

	if (length < sizeof(command) - 1 ||
	    memcmp(buffer, command, sizeof(command) - 1) != 0)
		return 0;

	for (index = sizeof(command) - 1; index < length; index++) {
		if (buffer[index] != '\r' && buffer[index] != '\n')
			return 0;
	}

	buffer[sizeof(command) - 2] = '4';
	return 1;
}

#ifndef UNIT_TEST
static int is_fm350_at_fd(int fd)
{
	const char *expected = getenv("GL_MODEM_FM350_AT_PORT");
	char fd_path[32];
	char target[PATH_MAX];
	ssize_t length;

	if (!expected || !*expected)
		return 0;

	if (snprintf(fd_path, sizeof(fd_path), "/proc/self/fd/%d", fd) < 0)
		return 0;

	length = readlink(fd_path, target, sizeof(target) - 1);
	if (length < 0)
		return 0;
	target[length] = '\0';
	return strcmp(target, expected) == 0;
}

ssize_t write(int fd, const void *buffer, size_t length)
{
	unsigned char rewritten[32];

	if (length <= sizeof(rewritten) && is_fm350_at_fd(fd)) {
		memcpy(rewritten, buffer, length);
		if (fm350_rewrite_tx(rewritten, length))
			return syscall(SYS_write, fd, rewritten, length);
	}

	return syscall(SYS_write, fd, buffer, length);
}
#endif
