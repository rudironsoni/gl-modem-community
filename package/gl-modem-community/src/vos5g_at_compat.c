// SPDX-License-Identifier: GPL-3.0-only

#define _GNU_SOURCE

#include <stddef.h>
#include <string.h>

static int find_line_end(const unsigned char *buffer, size_t length,
			 size_t start, size_t *end)
{
	size_t index;

	for (index = start; index < length; index++) {
		if (buffer[index] == '\r' || buffer[index] == '\n') {
			*end = index;
			return 1;
		}
	}
	return 0;
}

int vos5g_rewrite_rx(unsigned char *buffer, size_t *length, size_t capacity)
{
	static const char prefix[] = "+CGPADDR:";
	size_t current = *length;
	size_t search = 0;
	int changed = 0;

	while (search + sizeof(prefix) - 1 <= current) {
		size_t found;
		size_t cursor;
		size_t line_end;
		size_t field_start[4];
		size_t field_end[4];
		size_t field_count = 0;
		size_t extra = 0;
		size_t index;

		for (found = search; found + sizeof(prefix) - 1 <= current;
		     found++) {
			if (memcmp(buffer + found, prefix, sizeof(prefix) - 1) == 0)
				break;
		}
		if (found + sizeof(prefix) - 1 > current)
			break;

		cursor = found + sizeof(prefix) - 1;
		if (!find_line_end(buffer, current, cursor, &line_end))
			break;
		while (cursor < line_end &&
		       (buffer[cursor] == ' ' || buffer[cursor] == '\t'))
			cursor++;
		while (cursor < line_end &&
		       buffer[cursor] >= '0' && buffer[cursor] <= '9')
			cursor++;
		if (cursor >= line_end || buffer[cursor] != ',') {
			search = line_end + 1;
			continue;
		}
		cursor++;
		if (cursor < line_end && buffer[cursor] == '"') {
			search = line_end + 1;
			continue;
		}

		while (cursor < line_end && field_count < 4) {
			size_t start = cursor;
			size_t end;

			while (start < line_end &&
			       (buffer[start] == ' ' || buffer[start] == '\t'))
				start++;
			end = start;
			while (end < line_end && buffer[end] != ',')
				end++;
			while (end > start &&
			       (buffer[end - 1] == ' ' || buffer[end - 1] == '\t'))
				end--;
			if (end > start && buffer[start] != '"') {
				field_start[field_count] = start;
				field_end[field_count] = end;
				field_count++;
				extra += 2;
			}
			cursor = end;
			while (cursor < line_end && buffer[cursor] != ',')
				cursor++;
			if (cursor < line_end)
				cursor++;
		}

		if (field_count == 0 || current + extra > capacity) {
			search = line_end + 1;
			continue;
		}

		for (index = field_count; index > 0; index--) {
			size_t start = field_start[index - 1];
			size_t end = field_end[index - 1];

			memmove(buffer + end + 1, buffer + end, current - end);
			buffer[end] = '"';
			current++;
			memmove(buffer + start + 1, buffer + start, current - start);
			buffer[start] = '"';
			current++;
		}
		changed = 1;
		search = line_end + extra + 1;
	}

	*length = current;
	return changed;
}

#ifndef UNIT_TEST
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

static int is_vos5g_at_fd(int fd)
{
	const char *expected = getenv("GL_MODEM_VOS5G_AT_PORT");
	char fd_path[32];
	char target[PATH_MAX];
	ssize_t target_length;

	if (!expected || !*expected)
		return 0;
	if (snprintf(fd_path, sizeof(fd_path), "/proc/self/fd/%d", fd) < 0)
		return 0;
	target_length = readlink(fd_path, target, sizeof(target) - 1);
	if (target_length < 0)
		return 0;
	target[target_length] = '\0';
	return strcmp(target, expected) == 0;
}

ssize_t read(int fd, void *buffer, size_t length)
{
	ssize_t result = syscall(SYS_read, fd, buffer, length);
	size_t rewritten;

	if (result <= 0 || !is_vos5g_at_fd(fd))
		return result;
	rewritten = (size_t)result;
	vos5g_rewrite_rx(buffer, &rewritten, length);
	return (ssize_t)rewritten;
}
#endif
