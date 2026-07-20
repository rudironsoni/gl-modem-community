// SPDX-License-Identifier: GPL-3.0-only

#include <stddef.h>
#include <string.h>

static int rewrite_prefix(unsigned char *buffer, size_t length,
			  const char *prefix, size_t cid_offset,
			  unsigned char from, unsigned char to)
{
	size_t prefix_length = strlen(prefix);

	if (length < prefix_length || memcmp(buffer, prefix, prefix_length) != 0 ||
	    cid_offset >= length || buffer[cid_offset] != from)
		return 0;
	if (length > prefix_length && buffer[prefix_length] != ',' &&
	    buffer[prefix_length] != '\r' && buffer[prefix_length] != '\n')
		return 0;

	buffer[cid_offset] = to;
	return 1;
}

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
	int changed = 0;

	if (length >= sizeof(command) - 1 &&
	    memcmp(buffer, command, sizeof(command) - 1) == 0) {
		for (index = sizeof(command) - 1; index < length; index++) {
			if (buffer[index] != '\r' && buffer[index] != '\n')
				break;
		}
		if (index == length) {
			buffer[sizeof(command) - 2] = '4';
			changed = 1;
		}
	}

	changed |= rewrite_prefix(buffer, length, "AT+CGPADDR=5", 11, '5', '1');
	changed |= rewrite_prefix(buffer, length, "AT+CGDCONT=5", 11, '5', '1');
	changed |= rewrite_prefix(buffer, length, "AT+CGAUTH=5", 10, '5', '1');
	changed |= rewrite_prefix(buffer, length, "AT+CGCONTRDP=5", 13, '5', '1');
	changed |= rewrite_prefix(buffer, length, "AT+GTDNS=5", 9, '5', '1');
	changed |= rewrite_prefix(buffer, length, "AT+CGACT=0,5", 11, '5', '1');
	changed |= rewrite_prefix(buffer, length, "AT+CGACT=1,5", 11, '5', '1');
	return changed;
}

int fm350_rewrite_rx(unsigned char *buffer, size_t length)
{
	static const char *const prefixes[] = {
		"+CGPADDR: 1,",
		"+CGDCONT: 1,",
		"+CGACT: 1,",
		"+CGCONTRDP: 1,",
		"+GTDNS: 1,",
	};
	size_t index;
	int changed = 0;

	for (index = 0; index < sizeof(prefixes) / sizeof(prefixes[0]); index++) {
		const char *prefix = prefixes[index];
		size_t prefix_length = strlen(prefix);
		size_t offset;

		for (offset = 0; offset + prefix_length <= length; offset++) {
			if (memcmp(buffer + offset, prefix, prefix_length) == 0) {
				buffer[offset + prefix_length - 2] = '5';
				changed = 1;
			}
		}
	}

	return changed;
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

ssize_t read(int fd, void *buffer, size_t length)
{
	ssize_t result = syscall(SYS_read, fd, buffer, length);

	if (result > 0 && is_fm350_at_fd(fd))
		fm350_rewrite_rx(buffer, (size_t)result);

	return result;
}
#endif
