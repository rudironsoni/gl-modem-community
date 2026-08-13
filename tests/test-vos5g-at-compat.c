// SPDX-License-Identifier: GPL-3.0-only

#include <assert.h>
#include <stddef.h>
#include <string.h>

int vos5g_rewrite_rx(unsigned char *buffer, size_t *length, size_t capacity);

static void expect_rewrite(const char *input, const char *expected, int changed)
{
	unsigned char buffer[512];
	size_t length = strlen(input);
	size_t expected_length = strlen(expected);

	assert(length < sizeof(buffer));
	memcpy(buffer, input, length);
	assert(vos5g_rewrite_rx(buffer, &length, sizeof(buffer)) == changed);
	assert(length == expected_length);
	assert(memcmp(buffer, expected, expected_length) == 0);
}

int main(void)
{
	unsigned char tight[] = "+CGPADDR: 1,192.0.2.1\r\n";
	size_t tight_length = sizeof(tight) - 1;

	expect_rewrite("\r\n+CGPADDR: 1,192.0.2.42\r\nOK\r\n",
		"\r\n+CGPADDR: 1,\"192.0.2.42\"\r\nOK\r\n", 1);
	expect_rewrite(
		"+CGPADDR: 1,192.0.2.42,32.1.13.184.0.0.0.1\r\n",
		"+CGPADDR: 1,\"192.0.2.42\",\"32.1.13.184.0.0.0.1\"\r\n",
		1);
	expect_rewrite("+CGPADDR: 1,\"192.0.2.42\"\r\n",
		"+CGPADDR: 1,\"192.0.2.42\"\r\n", 0);
	expect_rewrite("+CGACT: 1,1\r\n", "+CGACT: 1,1\r\n", 0);
	expect_rewrite("+CGPADDR: 1,192.0.2.42",
		"+CGPADDR: 1,192.0.2.42", 0);
	assert(!vos5g_rewrite_rx(tight, &tight_length, tight_length));
	assert(tight_length == sizeof(tight) - 1);
	return 0;
}
