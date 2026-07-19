// SPDX-License-Identifier: GPL-3.0-only

#include <assert.h>
#include <stddef.h>
#include <string.h>

int fm350_rewrite_tx(unsigned char *buffer, size_t length);

static void expect_rewrite(const char *input, const char *expected, int changed)
{
	unsigned char buffer[128];
	size_t length = strlen(input);

	assert(length < sizeof(buffer));
	memcpy(buffer, input, length + 1);
	assert(fm350_rewrite_tx(buffer, length) == changed);
	assert(memcmp(buffer, expected, length) == 0);
}

int main(void)
{
	expect_rewrite("AT+CFUN=0\r", "AT+CFUN=4\r", 1);
	expect_rewrite("AT+CFUN=1\r", "AT+CFUN=1\r", 0);
	expect_rewrite("AT+CGDCONT=1,\"IP\",\"orangeworld\"\r",
		"AT+CGDCONT=1,\"IP\",\"orangeworld\"\r", 0);
	expect_rewrite("prefix AT+CFUN=0 suffix", "prefix AT+CFUN=0 suffix", 0);
	return 0;
}
