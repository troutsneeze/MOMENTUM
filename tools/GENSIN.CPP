// This generates the sin table hard-coded in the ASM file

#include <cstdio>
#include <cmath>

const int PERIOD = 80;
const int AMP = 5;

int main()
{
	for (int i = 0; i < PERIOD; i++) {
		float f = (float)i/(PERIOD-1);
		f = sin(f*M_PI*2) * AMP;
		printf("%d,", (int)f);
	}

	return 0;
}
