// SPDX-License-Identifier: GPL-3.0-only

#include <stddef.h>
#include <string.h>

static int command_matches(const unsigned char *buffer, size_t length,
			   const char *command)
{
	size_t command_length = strlen(command);
	size_t index;

	if (length < command_length ||
	    memcmp(buffer, command, command_length) != 0)
		return 0;

	for (index = command_length; index < length; index++)
		if (buffer[index] != '\r' && buffer[index] != '\n')
			return 0;

	return 1;
}

static int rewrite_prefix(unsigned char *buffer, size_t length,
			  const char *prefix, size_t cid_offset,
			  unsigned char from, unsigned char to)
{
	size_t prefix_length = strlen(prefix);

	if (length < prefix_length ||
	    memcmp(buffer, prefix, prefix_length) != 0 ||
	    cid_offset >= length || buffer[cid_offset] != from)
		return 0;

	if (length > prefix_length && buffer[prefix_length] != ',' &&
	    buffer[prefix_length] != '\r' && buffer[prefix_length] != '\n')
		return 0;

	buffer[cid_offset] = to;
	return 1;
}

int fm350_command_needs_synthetic_ok(const unsigned char *buffer,
				     size_t length)
{
	return command_matches(buffer, length, "AT+CGACT=0,5") ||
	       command_matches(buffer, length, "AT+CGACT=1,5") ||
	       command_matches(buffer, length, "AT+CGACT=0,1") ||
	       command_matches(buffer, length, "AT+CGACT=1,1");
}

int fm350_rewrite_tx(unsigned char *buffer, size_t length)
{
	int changed = 0;

	if (command_matches(buffer, length, "AT+CFUN=0")) {
		buffer[sizeof("AT+CFUN=0") - 2] = '4';
		changed = 1;
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
	size_t prefix;
	size_t index;
	int changed = 0;

	for (prefix = 0; prefix < sizeof(prefixes) / sizeof(prefixes[0]);
	     prefix++) {
		size_t prefix_length = strlen(prefixes[prefix]);

		for (index = 0; index + prefix_length <= length; index++) {
			if (memcmp(buffer + index, prefixes[prefix],
				   prefix_length) != 0)
				continue;

			buffer[index + prefix_length - 2] = '5';
			changed = 1;
		}
	}

	return changed;
}

#ifndef UNIT_TEST
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

static int pending_ok_fd = -1;
static size_t pending_ok_offset;
static const unsigned char synthetic_ok[] = "\r\nOK\r\n";

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
	const void *output = buffer;
	int synthetic = 0;
	ssize_t result;

	if (length <= sizeof(rewritten) && is_fm350_at_fd(fd)) {
		synthetic = fm350_command_needs_synthetic_ok(buffer, length);
		memcpy(rewritten, buffer, length);
		if (fm350_rewrite_tx(rewritten, length))
			output = rewritten;
	}

	result = syscall(SYS_write, fd, output, length);
	if (result == (ssize_t)length && synthetic) {
		pending_ok_offset = 0;
		__atomic_store_n(&pending_ok_fd, fd, __ATOMIC_RELEASE);
	}

	return result;
}

ssize_t read(int fd, void *buffer, size_t length)
{
	ssize_t result;

	if (length > 0 &&
	    __atomic_load_n(&pending_ok_fd, __ATOMIC_ACQUIRE) == fd) {
		size_t remaining = sizeof(synthetic_ok) - 1 - pending_ok_offset;
		size_t copied = length < remaining ? length : remaining;

		memcpy(buffer, synthetic_ok + pending_ok_offset, copied);
		pending_ok_offset += copied;
		if (pending_ok_offset == sizeof(synthetic_ok) - 1)
			__atomic_store_n(&pending_ok_fd, -1, __ATOMIC_RELEASE);

		return (ssize_t)copied;
	}

	result = syscall(SYS_read, fd, buffer, length);
	if (result > 0 && is_fm350_at_fd(fd))
		fm350_rewrite_rx(buffer, (size_t)result);

	return result;
}
#endif
