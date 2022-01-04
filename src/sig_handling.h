
#ifdef STATS
#ifndef FLAGLOADSIGHANDLER_H
#include <signal.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <time.h>

#ifdef POSIT
extern int POSIT_n;
#endif

#ifdef BOHM
extern int BOHM_alpha;
extern int BOHM_beta;
#endif

extern char* filename;
extern int mem_used;
extern int nConflicts;
extern int maxLemmas;
extern int nRestarts;

extern clock_t solve_tic;
extern clock_t solve_toc;
extern double solving_time;

#if defined MRC || defined MRC_DYN || defined MRC_GPU
extern double miracle_time;

extern double max_inc_dec_lvl_time;
extern double min_inc_dec_lvl_time;
extern double avg_inc_dec_lvl_time;
extern double tot_inc_dec_lvl_time;
extern int num_inc_dec_lvl;

extern double max_assign_time;
extern double min_assign_time;
extern double avg_assign_time;
extern double tot_assign_time;
extern int num_assign;

extern double max_bj_time;
extern double min_bj_time;
extern double avg_bj_time;
extern double tot_bj_time;
extern int num_bj;
#endif

extern double max_heur_time;
extern double min_heur_time;
extern double avg_heur_time;
extern double tot_heur_time;
extern int num_heur;

extern int timeout_expired;
extern int escape;
extern int timeout;

extern void print_stats();


void install_alarmhandler();
void install_handler();

void my_catchint(int signo);
void my_catchalarm(int signo);




void install_handler() {

  static struct sigaction act;
  act.sa_handler = my_catchint; /* registrazione dell'handler */

  sigfillset(&(act.sa_mask)); /* tutti i segnali saranno ignorati
                                 DURANTE l'esecuzione dell'handler */

  /* imposto l'handler per il segnale SIGINT */
  sigaction(SIGINT, &act, NULL); 

}

void install_alarmhandler() {

  static struct sigaction act;
  act.sa_handler = my_catchalarm;
  sigfillset(&(act.sa_mask));
  sigaction(SIGALRM, &act, NULL); 
}

 /* Questo e' l'handler. Semplice. */
void my_catchint(int signo) {
	if ((signo==SIGINT)) {
    solve_toc = clock();
    solving_time = ((double)(solve_toc - solve_tic)) / CLOCKS_PER_SEC;  // In s.
    solving_time *= 1000;   // In ms.

		escape = 1;
		fprintf(stderr,"\nCATCHING SIG_INT: forced exit.\n");fflush(stderr);

    printf ("c statistics of %s: mem: %i conflicts: %i max_lemmas: %i restarts: %i\n", filename, mem_used, nConflicts, maxLemmas, nRestarts);
    printf("\n");
    print_stats();

    // exit(2);
	}
}


void my_catchalarm(int signo) {
	if ((signo==SIGALRM)) {
    solve_toc = clock();
    solving_time = ((double)(solve_toc - solve_tic)) / CLOCKS_PER_SEC;  // In s.
    solving_time *= 1000;   // In ms.

		timeout_expired = 1;
		fprintf(stderr,"\nTIMEOUT EXPIRED: forced exit.\n");fflush(stderr);

    printf ("c statistics of %s: mem: %i conflicts: %i max_lemmas: %i restarts: %i\n", filename, mem_used, nConflicts, maxLemmas, nRestarts);
    printf("\n");
    print_stats();

		// exit(2);
	}
}


#define FLAGLOADSIGHANDLER_H 1
#endif
#endif
