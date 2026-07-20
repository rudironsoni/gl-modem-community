// SPDX-License-Identifier: GPL-3.0-only

#include <assert.h>
#include <stddef.h>
#include <string.h>

int fm350_rewrite_tx(unsigned char *buffer, size_t length);
int fm350_rewrite_rx(unsigned char *buffer, size_t length);
int fm350_command_needs_synthetic_ok(const unsigned char *buffer,
				     size_t length);

static void expect_rewrite(const char *input, const char *expected, int changed)
{
	unsigned char buffer[128];
	size_t length = strlen(input);

	assert(length < sizeof(buffer));
	memcpy(buffer, input, length + 1);
	assert(fm350_rewrite_tx(buffer, length) == changed);
	assert(memcmp(buffer, expected, length) == 0);
}

static void expect_rx_rewrite(const char *input, const char *expected,
			      int changed)
{
	unsigned char buffer[256];
	size_t length = strlen(input);

	assert(length < sizeof(buffer));
	memcpy(buffer, input, length + 1);
	assert(fm350_rewrite_rx(buffer, length) == changed);
	assert(memcmp(buffer, expected, length) == 0);
}

int main(void)
{
	assert(fm350_command_needs_synthetic_ok(
		       (const unsigned char *)"AT+CGACT=1,5\r",
		       strlen("AT+CGACT=1,5\r")));
	assert(fm350_command_needs_synthetic_ok(
		       (const unsigned char *)"AT+CGACT=0,1\r\n",
		       strlen("AT+CGACT=0,1\r\n")));
	assert(!fm350_command_needs_synthetic_ok(
			(const unsigned char *)"AT+CGACT?\r",
			strlen("AT+CGACT?\r")));
	assert(!fm350_command_needs_synthetic_ok(
			(const unsigned char *)"AT+CGACT=1,50\r",
			strlen("AT+CGACT=1,50\r")));

	expect_rewrite("AT+CFUN=0\r", "AT+CFUN=4\r", 1);
	expect_rewrite("AT+CFUN=1\r", "AT+CFUN=1\r", 0);
	expect_rewrite("AT+CGDCONT=1,\"IP\",\"orangeworld\"\r",
		"AT+CGDCONT=1,\"IP\",\"orangeworld\"\r", 0);
	expect_rewrite("AT+CGDCONT=5,\"IP\",\"orangeworld\"\r",
		"AT+CGDCONT=1,\"IP\",\"orangeworld\"\r", 1);
	expect_rewrite("AT+CGACT=1,5\r", "AT+CGACT=1,1\r", 1);
	expect_rewrite("AT+CGPADDR=5\r", "AT+CGPADDR=1\r", 1);
	expect_rewrite("AT+CGPADDR=50\r", "AT+CGPADDR=50\r", 0);
	expect_rewrite("AT+CGCONTRDP=5\r", "AT+CGCONTRDP=1\r", 1);
	expect_rewrite("AT+GTDNS=5\r", "AT+GTDNS=1\r", 1);
	expect_rewrite("prefix AT+CFUN=0 suffix", "prefix AT+CFUN=0 suffix", 0);
	expect_rx_rewrite("\r\n+CGDCONT: 1,\"IP\",\"orangeworld\"\r\nOK\r\n",
		"\r\n+CGDCONT: 5,\"IP\",\"orangeworld\"\r\nOK\r\n", 1);
	expect_rx_rewrite("\r\n+CGACT: 1,1\r\n+CGPADDR: 1,\"10.21.90.110\"\r\n",
		"\r\n+CGACT: 5,1\r\n+CGPADDR: 5,\"10.21.90.110\"\r\n", 1);
	expect_rx_rewrite("\r\n+GTDNS: 1,\"86.104.186.208\"\r\n",
		"\r\n+GTDNS: 5,\"86.104.186.208\"\r\n", 1);
	expect_rx_rewrite("\r\nOK\r\n", "\r\nOK\r\n", 0);
	return 0;
}
