#include <stdio.h>
#include <float.h>

#define MAX_SIZE 1000
#define NBIN 120

struct winner { int cnt; float val; };
int main() {
    float numbers[MAX_SIZE];
    int count = 0;
    float num, min, max;

    // first pass. read in
    // need all in to get max
    while (scanf("%f", &num) == 1) {
        if (count == MAX_SIZE) {
            printf("Exceded max input %i\n", MAX_SIZE);
            return 1;
        }
        if(count>1 && numbers[count-1] > num){
            printf("Numbers are not sorted @ line %i %.3f > %.3f\n",
                   count, numbers[count-1] > num);
            return 2;
        }

        numbers[count++] = num;
    }

    if (count == 0) {
        printf("No numbers were entered.\n");
        return 3;
    }

    min = numbers[0]; max=numbers[count-1];
    float binsize = (max - min)/NBIN;
    float cur_bin = min;
    int cur_cnt = 0;
    struct winner w; w.cnt = 0; w.val = cur_bin;

    //printf("# %d lines; values %.3f to %.3f; NBIN in steps of size %.3f\n", count, min, max, binsize);
    int i=0;
    while(i < count){
      if(numbers[i] >= cur_bin) {
        cur_bin += binsize;
        //printf("@%d %f inc cur bin to %f (step size %f)\n", i, numbers[i], cur_bin, binsize);
        cur_cnt = 0;
        continue;
      }
      ++i;
      ++cur_cnt;
      if(cur_cnt > w.cnt){
        w.val = cur_bin;
        w.cnt = cur_cnt;
      }

      //TODO: leave loop early if w.val + i > count ?
    }
    printf("%d\t%.3f\t%.3f\n", w.cnt, w.val, w.val + binsize);

    return 0;
 }
