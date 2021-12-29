/*********************************************************************[microsat.c]***

  The MIT License

  Copyright (c) 2014-2018 Marijn Heule

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

*************************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>

/**
 * Parameters
 */

// Specify how to compute the heuristic.
// #define NO_MRC
// #define MRC
// #define MRC_DYN
// #define MRC_GPU

// Specify the heuristic.
// #define JW_OS
// #define JW_TS
// #define BOHM
// #define POSIT
// #define DLIS
// #define DLCS
// #define RDLIS
// #define RDLCS

// Enable statistics.
// #define STATS

#ifdef MRC_GPU
#define NUM_THREADS_PER_BLOCK (512)
#endif
#ifdef POSIT
#define POSIT_N (8)
#endif
#ifdef BOHM
#define BOHM_ALPHA (1)
#define BOHM_BETA (2)
#endif
#ifdef STATS
#define TIMEOUT (1800)    // In s.
#endif

/**
 * End parameters
 */

#include "utils.cuh"
#include "sig_handling.h"
#ifdef MRC
#include "miracle.cuh"
#endif
#ifdef MRC_DYN
#include "miracle_dynamic.cuh"
#endif
#ifdef MRC_GPU
#include "miracle.cuh"
#include "miracle_gpu.cuh"
#include "launch_parameters_gpu.cuh"
#endif

#ifdef MRC_GPU
int num_threads_per_block;    // Number of threads per block.
static int *d_var_ass;        // d_mrc->var_ass on the host.
#endif

#ifdef POSIT
int POSIT_n;                  // Constant of the POSIT weight function.
#endif

#ifdef BOHM
int BOHM_alpha;               // Constant of the BOHM weight function.
int BOHM_beta;                // Constant of the BOHM weight function.
#endif

#if defined MRC || defined MRC_DYN || defined MRC_GPU
static Lit *lits;             // Array of assigned literals.
static int lits_len;          // Length of lits, which is the number of assigned literals.
#endif

#ifdef STATS
char* filename;               // Filename of the DIMACS CNF formula.
int mem_used;                 // The number of integers allocated in the DB
int nConflicts;               // Number of conflicts which is used to updates scores
int maxLemmas;                // Initial maximum number of learnt clauses
int nRestarts;                // The number of restarts performed

clock_t solve_tic;            // Solving time in clock.
clock_t solve_toc;            // Solving time out clock.
double solving_time;          // Solving time.

#if defined MRC || defined MRC_DYN || defined MRC_GPU
double miracle_time;          // MiraCle time.

clock_t inc_dec_lvl_tic;      // Decision level increase time in clock.
clock_t inc_dec_lvl_toc;      // Decision level increase time out clock.
double inc_dec_lvl_time;      // Decision level increase time.
double max_inc_dec_lvl_time;  // Maximum decision level increase time.
double min_inc_dec_lvl_time;  // Minimum decision level increase time.
double avg_inc_dec_lvl_time;  // Average decision level increase time.
double tot_inc_dec_lvl_time;  // Total decision level increase time.
int num_inc_dec_lvl;          // Number of increase decision level calls.
static int inc_dec_lvl_f;     // Flag for increase decision level.

clock_t assign_tic;           // Assignment time in clock.
clock_t assign_toc;           // Assignment time out clock.
double assign_time;           // Assignment time.
double max_assign_time;       // Maximum assignment time.
double min_assign_time;       // Minimum assignment time.
double avg_assign_time;       // Average assignment time.
double tot_assign_time;       // Total assignment time.
int num_assign;               // Number of assignment calls.
static int assign_f;          // Flag for assignment.

clock_t bj_tic;               // Backjumping time in clock.
clock_t bj_toc;               // Backjumping time out clock.
double bj_time;               // Backjumping time.
double max_bj_time;           // Maximum backjumping time.
double min_bj_time;           // Minimum backjumping time.
double avg_bj_time;           // Average backjumping time.
double tot_bj_time;           // Total backjumping time.
int num_bj;                   // Number of backjumping calls.
static int bj_f;              // Flag for backjumping.
#endif

clock_t heur_tic;             // Heuristic time in clock.
clock_t heur_toc;             // Heuristic time out clock.
double heur_time;             // Heuristic time.
double max_heur_time;         // Maximum heuristic time.
double min_heur_time;         // Minimum heuristic time.
double avg_heur_time;         // Average heuristic time.
double tot_heur_time;         // Total heuristic time.
int num_heur;                 // Number of heuristic calls.

int timeout_expired;          // Flag for timeout expiration.
int escape;                   // Flag for SIGINT.
int timeout;                  // In s.

void print_stats() {          // Print solving statistics
    printf("****************************************************************");
    printf("\n");
    printf("************************    STATS    ***************************");
    printf("\n");
    printf("****************************************************************");
    printf("\n\n");

    if (timeout_expired) {
        printf("Timeout expired: YES\n");
    } else {
        printf("Timeout expired: NO\n");
    }

    if (escape) {
        printf("SIGINT captured: YES\n");
        } else {
        printf("SIGINT captured: NO\n");
    }

    printf("Timeout: %d s\n", timeout);
#ifdef MRC_GPU
    printf("Number of threads per block: %d\n", gpu_num_threads_per_block());
#endif
#ifdef POSIT
    printf("POSIT n: %d\n", POSIT_n);
#endif
#ifdef BOHM
    printf("BOHM alpha: %d\n", BOHM_alpha);
    printf("BOHM beta: %d\n", BOHM_beta);
#endif
    printf("\n");

    printf("Solving time: %f ms\n", solving_time);
    printf("\n");

#if defined MRC || defined MRC_DYN || defined MRC_GPU
    printf("MiraCle time: %f ms\n", miracle_time);
    printf("%% of solving time used in MiraCle calls: %f %%\n",
           (miracle_time * 100) / solving_time);
    printf("\n");

    printf("Maximum decision level increase time: %f ms\n", max_inc_dec_lvl_time);
    printf("Minimum decision level increase time: %f ms\n", min_inc_dec_lvl_time);
    avg_inc_dec_lvl_time = tot_inc_dec_lvl_time / num_inc_dec_lvl;
    printf("Average decision level increase time: %f ms\n", avg_inc_dec_lvl_time);
    printf("Total decision level increase time: %f ms\n", tot_inc_dec_lvl_time);
    printf("%% of MiraCle time used in increase decision level calls: %f %%\n",
           (tot_inc_dec_lvl_time * 100) / miracle_time);
    printf("Number of increase decision level calls: %d\n", num_inc_dec_lvl);
    printf("\n");

    printf("Maximum assignment time: %f ms\n", max_assign_time);
    printf("Minimum assignment time: %f ms\n", min_assign_time);
    avg_assign_time = tot_assign_time / num_assign;
    printf("Average assignment time: %f ms\n", avg_assign_time);
    printf("Total assignment time: %f ms\n", tot_assign_time);
    printf("%% of MiraCle time used in assignment calls: %f %%\n",
           (tot_assign_time * 100) / miracle_time);
    printf("Number of assignment calls: %d\n", num_assign);
    printf("\n");

    printf("Maximum backjumping time: %f ms\n", max_bj_time);
    printf("Minimum backjumping time: %f ms\n", min_bj_time);
    avg_bj_time = tot_bj_time / num_bj;
    printf("Average backjumping time: %f ms\n", avg_bj_time);
    printf("Total backjumping time: %f ms\n", tot_bj_time);
    printf("%% of MiraCle time used in backjumping calls: %f %%\n",
           (tot_bj_time * 100) / miracle_time);
    printf("Number of backjumping calls: %d\n", num_bj);
    printf("\n");
#endif

    printf("Maximum heuristic time: %f ms\n", max_heur_time);
    printf("Minimum heuristic time: %f ms\n", min_heur_time);
    avg_heur_time = tot_heur_time / num_heur;
    printf("Average heuristic time: %f ms\n", avg_heur_time);
    printf("Total heuristic time: %f ms\n", tot_heur_time);
#if defined MRC || defined MRC_DYN || defined MRC_GPU
    printf("%% of MiraCle time used in heuristic calls: %f %%\n",
           (tot_heur_time * 100) / miracle_time);
#endif
#ifdef NO_MRC
    printf("%% of solving time used in heuristic calls: %f %%\n",
           (tot_heur_time * 100) / solving_time);
#endif
    printf("Number of heuristic calls: %d\n", num_heur);
    printf("\n");

    printf("****************************************************************");
    printf("\n");
    printf("**********************    END STATS    *************************");
    printf("\n");
    printf("****************************************************************");
    printf("\n\n");
}
#endif

enum { END = -9, UNSAT = 0, SAT = 1, MARK = 2, IMPLIED = 6, MEM_MAX = (1 << 30) };

struct solver { // The variables in the struct are described in the allocate procedure
  int  *DB, nVars, nClauses, mem_used, mem_fixed, maxLemmas, nLemmas, *buffer, nConflicts, *model,
       *reason, *falseStack, *falselit, *first, *forced, *processed, *assigned, *next, *prev, head, res, fast, slow, nRestarts; };

void unassign (struct solver* S, int lit) { S->falselit[lit] = 0; }   // Unassign the literal

void restart (struct solver* S) {                                     // Perform a restart (i.e., unassign all variables)
  while (S->assigned > S->forced) unassign (S, *(--S->assigned));     // Remove all unforced false lits from falseStack
  S->processed = S->forced; }                                         // Reset the processed pointer

void assign (struct solver* S, int* reason, int forced) {             // Make the first literal of the reason true
  int lit = reason[0];                                                // Let lit be the first literal in the reason
  S->falselit[-lit] = forced ? IMPLIED : 1;                           // Mark lit as true and IMPLIED if forced
  *(S->assigned++) = -lit;                                            // Push it on the assignment stack
  S->reason[abs (lit)] = 1 + (int) ((reason)-S->DB);                  // Set the reason clause of lit
  S->model [abs (lit)] = (lit > 0); }                                 // Mark the literal as true in the model

void addWatch (struct solver* S, int lit, int mem) {                  // Add a watch pointer to a clause containing lit
  S->DB[mem] = S->first[lit]; S->first[lit] = mem; }                  // By updating the database and the pointers

int* getMemory (struct solver* S, int mem_size) {                     // Allocate memory of size mem_size
  if (S->mem_used > MEM_MAX - mem_size) {                             // In case the code is used within a code base
    printf ("c out of memory\n"); exit (1); }
  int *store = (S->DB + S->mem_used);                                 // Compute a pointer to the new memory location
  S->mem_used += mem_size;                                            // Update the size of the used memory
#ifdef STATS
  mem_used = S->mem_used;
#endif
  return store; }                                                     // Return the pointer

int* addClause (struct solver* S, int* in, int size, int irr) {       // Adds a clause stored in *in of size size
  int i, used = S->mem_used;                                          // Store a pointer to the beginning of the clause
  int* clause = getMemory (S, size + 3) + 2;                          // Allocate memory for the clause in the database
  if (size >  1) { addWatch (S, in[0], used  );                       // If the clause is not unit, then add
                   addWatch (S, in[1], used+1); }                     // Two watch pointers to the datastructure
  for (i = 0; i < size; i++) clause[i] = in[i]; clause[i] = 0;        // Copy the clause from the buffer to the database
  if (irr) S->mem_fixed = S->mem_used; else S->nLemmas++;             // Update the statistics
  return clause; }                                                    // Return the pointer to the clause in the database

void reduceDB (struct solver* S, int k) {                     // Removes "less useful" lemmas from DB
  while (S->nLemmas > S->maxLemmas) S->maxLemmas += 300;      // Allow more lemmas in the future
#ifdef STATS
  maxLemmas = S->maxLemmas;
#endif
  S->nLemmas = 0;                                             // Reset the number of lemmas

  int i; for (i = -S->nVars; i <= S->nVars; i++) {            // Loop over the variables
    if (i == 0) continue; int* watch = &S->first[i];          // Get the pointer to the first watched clause
    while (*watch != END)                                     // As long as there are watched clauses
      if (*watch < S->mem_fixed) watch = (S->DB + *watch);    // Remove the watch if it points to a lemma
      else                      *watch =  S->DB[  *watch]; }  // Otherwise (meaning an input clause) go to next watch

  int old_used = S->mem_used; S->mem_used = S->mem_fixed;     // Virtually remove all lemmas
#ifdef STATS
  mem_used = S->mem_used;
#endif
  for (i = S->mem_fixed + 2; i < old_used; i += 3) {          // While the old memory contains lemmas
    int count = 0, head = i;                                  // Get the lemma to which the head is pointing
    while (S->DB[i]) { int lit = S->DB[i++];                  // Count the number of literals
      if ((lit > 0) == S->model[abs (lit)]) count++; }        // That are satisfied by the current model
    if (count < k) addClause (S, S->DB+head, i-head, 0); } }  // If the latter is smaller than k, add it back

void bump (struct solver* S, int lit) {                       // Move the variable to the front of the decision list
  if (S->falselit[lit] != IMPLIED) { S->falselit[lit] = MARK; // MARK the literal as involved if not a top-level unit
#ifdef NO_MRC
    int var = abs (lit); if (var != S->head) {                // In case var is not already the head of the list
      S->prev[S->next[var]] = S->prev[var];                   // Update the prev link, and
      S->next[S->prev[var]] = S->next[var];                   // Update the next link, and
      S->next[S->head] = var;                                 // Add a next link to the head, and
      S->prev[var] = S->head; S->head = var; }                // Make var the new head
#endif
  }
}

int implied (struct solver* S, int lit) {                           // Check if lit(eral) is implied by MARK literals
  if (S->falselit[lit] > MARK) return (S->falselit[lit] & MARK);    // If checked before return old result
  if (!S->reason[abs (lit)]) return 0;                              // In case lit is a decision, it is not implied
  int* p = (S->DB + S->reason[abs (lit)] - 1);                      // Get the reason of lit(eral)
  while (*(++p))                                                    // While there are literals in the reason
    if ((S->falselit[*p] ^ MARK) && !implied (S, *p)) {             // Recursively check if non-MARK literals are implied
      S->falselit[lit] = IMPLIED - 1; return 0; }                   // Mark and return not implied (denoted by IMPLIED - 1)
  S->falselit[lit] = IMPLIED; return 1; }                           // Mark and return that the literal is implied

int* analyze (struct solver* S, int* clause) {            // Compute a resolvent from falsified clause
  S->res++; S->nConflicts++;                              // Bump restarts and update the statistic
#ifdef STATS
  nConflicts = S->nConflicts;
#endif
  while (*clause) bump (S, *(clause++));                  // MARK all literals in the falsified clause
  while (S->reason[abs (*(--S->assigned))]) {             // Loop on variables on falseStack until the last decision
    if (S->falselit[*S->assigned] == MARK) {              // If the tail of the stack is MARK
      int *check = S->assigned;                           // Pointer to check if first-UIP is reached
      while (S->falselit[*(--check)] != MARK)             // Check for a MARK literal before decision
        if (!S->reason[abs(*check)]) goto build;          // Otherwise it is the first-UIP so break
      clause = S->DB + S->reason[abs (*S->assigned)];     // Get the reason and ignore first literal
      while (*clause) bump (S, *(clause++)); }            // MARK all literals in reason
    unassign (S, *S->assigned); }                         // Unassign the tail of the stack

  build:; int size = 0, lbd = 0, flag = 0;                // Build conflict clause; Empty the clause buffer
  int* p = S->processed = S->assigned;                    // Loop from tail to front
  while (p >= S->forced) {                                // Only literals on the stack can be MARKed
    if ((S->falselit[*p] == MARK) && !implied (S, *p)) {  // If MARKed and not implied
      S->buffer[size++] = *p; flag = 1; }                 // Add literal to conflict clause buffer
    if (!S->reason[abs (*p)]) { lbd += flag; flag = 0;    // Increase LBD for a decision with a true flag
      if (size == 1) S->processed = p; }                  // And update the processed pointer
    S->falselit[*(p--)] = 1; }                            // Reset the MARK flag for all variables on the stack

  S->fast -= S->fast >>  5; S->fast += lbd << 15;      // Update the fast moving average
  S->slow -= S->slow >> 15; S->slow += lbd <<  5;      // Update the slow moving average

  while (S->assigned > S->processed)                   // Loop over all unprocessed literals
    unassign (S, *(S->assigned--));                    // Unassign all lits between tail & head
  unassign (S, *S->assigned);                          // Assigned now equal to processed
  S->buffer[size] = 0;                                 // Terminate the buffer (and potentially print clause)
  return addClause (S, S->buffer, size, 0); }          // Add new conflict clause to redundant DB

int propagate (struct solver* S) {                  // Performs unit propagation
  int forced = S->reason[abs (*S->processed)];      // Initialize forced flag
  while (S->processed < S->assigned) {              // While unprocessed false literals
    int lit = *(S->processed++);                    // Get first unprocessed literal
    int* watch = &S->first[lit];                    // Obtain the first watch pointer
    while (*watch != END) {                         // While there are watched clauses (watched by lit)
      int i, unit = 1;                              // Let's assume that the clause is unit
      int* clause = (S->DB + *watch + 1);	          // Get the clause from DB
      if (clause[-2] ==   0) clause++;              // Set the pointer to the first literal in the clause
      if (clause[ 0] == lit) clause[0] = clause[1]; // Ensure that the other watched literal is in front
      for (i = 2; unit && clause[i]; i++)           // Scan the non-watched literals
        if (!S->falselit[clause[i]]) {              // When clause[i] is not false, it is either true or unset
          clause[1] = clause[i]; clause[i] = lit;   // Swap literals
          int store = *watch; unit = 0;             // Store the old watch
          *watch = S->DB[*watch];                   // Remove the watch from the list of lit
          addWatch (S, clause[1], store); }         // Add the watch to the list of clause[1]
      if (unit) {                                   // If the clause is indeed unit
        clause[1] = lit; watch = (S->DB + *watch);  // Place lit at clause[1] and update next watch
        if ( S->falselit[-clause[0]]) continue;     // If the other watched literal is satisfied continue
        if (!S->falselit[ clause[0]]) {             // If the other watched literal is falsified,
          assign (S, clause, forced); }             // A unit clause is found, and the reason is set
        else { if (forced) return UNSAT;            // Found a root level conflict -> UNSAT
          int* lemma = analyze (S, clause);	        // Analyze the conflict return a conflict clause
          if (!lemma[1]) forced = 1;                // In case a unit clause is found, set forced flag
          assign (S, lemma, forced); break; } } } } // Assign the conflict clause as a unit
  if (forced) S->forced = S->processed;	            // Set S->forced if applicable
  return SAT; }	                                    // Finally, no conflict was found

#ifdef NO_MRC
int solve (struct solver* S) {                                      // Determine satisfiability
#endif
#ifdef MRC
int solve (struct solver* S, Miracle *mrc) {
#endif
#ifdef MRC_DYN
int solve (struct solver* S, Miracle_Dyn *mrc_dyn) {
#endif
#ifdef MRC_GPU
int solve (struct solver* S, Miracle *d_mrc) {
#endif

#if defined MRC || defined MRC_DYN || defined MRC_GPU
  int *last_dec;
  Lit lit;
  Var last_bvar;
  int last_bvar_ass;
  int decision;
#endif

#ifdef NO_MRC
  int decision = S->head;                                           // Initialize the solver
#endif
  S->res = 0;
  for (;;) {                                                        // Main solve loop
    int old_nLemmas = S->nLemmas;                                   // Store nLemmas to see whether propagate adds lemmas
    if (propagate (S) == UNSAT) return UNSAT;                       // Propagation returns UNSAT for a root level conflict

    if (S->nLemmas > old_nLemmas) {                                 // If the last decision caused a conflict
#ifdef NO_MRC
      decision = S->head;                                           // Reset the decision heuristic to head
#endif
      if (S->fast > (S->slow / 100) * 125) {                        // If fast average is substantially larger than slow average
//        printf("c restarting after %i conflicts (%i %i) %i\n", S->res, S->fast, S->slow, S->nLemmas > S->maxLemmas);
        S->res = 0; S->fast = (S->slow / 100) * 125;                // Restart and update the averages
        restart (S); S->nRestarts++;
#ifdef STATS
        nRestarts = S->nRestarts;
#endif

#if defined MRC || defined MRC_DYN || defined MRC_GPU
        last_dec = S->forced - 1;
        lits_len = 0;

        while (last_dec >= S->falseStack) {
          lit = neg_lit(*last_dec);
          last_dec--;
          lits[lits_len] = lit;
          lits_len++;
        }
#endif
#ifdef MRC
#ifdef STATS
        bj_tic = clock();
#endif
        mrc_backjump(0, mrc);
#ifdef STATS
        bj_toc = clock();
        bj_f = 1;
#endif

        if (lits_len > 0) {
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_assign_lits(lits, lits_len, mrc);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        }
#endif
#ifdef MRC_DYN
#ifdef STATS
        bj_tic = clock();
#endif
        mrc_dyn_backjump(0, mrc_dyn);
#ifdef STATS
        bj_toc = clock();
        bj_f = 1;
#endif

        if (lits_len > 0) {
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_dyn_assign_lits(lits, lits_len, mrc_dyn);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        }
#endif
#ifdef MRC_GPU
#ifdef STATS
        bj_tic = clock();
#endif
        mrc_gpu_backjump(0, d_mrc);
#ifdef STATS
        bj_toc = clock();
        bj_f = 1;
#endif

        if (lits_len > 0) {
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_gpu_assign_lits(lits, lits_len, d_mrc);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        }
#endif
#if defined STATS && (defined MRC || defined MRC_DYN || defined MRC_GPU)
        if (bj_f) {
          num_bj++;
          bj_time = ((double)(bj_toc - bj_tic)) / CLOCKS_PER_SEC;   // In s.
          bj_time *= 1000;    // In ms.

          tot_bj_time += bj_time;
          miracle_time += bj_time;

          if (bj_time > max_bj_time) {
            max_bj_time = bj_time;
          }

          if (bj_time < min_bj_time) {
            min_bj_time = bj_time;
          }

          bj_f = 0;
        }

        if (assign_f) {
          num_assign++;
          assign_time = ((double)(assign_toc - assign_tic)) / CLOCKS_PER_SEC;   // In s.
          assign_time *= 1000;    // In ms.

          tot_assign_time += assign_time;
          miracle_time += assign_time;

          if (assign_time > max_assign_time) {
            max_assign_time = assign_time;
          }

          if (assign_time < min_assign_time) {
            min_assign_time = assign_time;
          }

          assign_f = 0;
        }
#endif

        if (S->nLemmas > S->maxLemmas) reduceDB (S, 6); } }         // Reduce the DB when it contains too many lemmas

#if defined MRC || defined MRC_DYN || defined MRC_GPU
    last_dec = S->assigned - 1;
    lits_len = 0;
    last_bvar = UNDEF_VAR;

    while (last_dec >= S->falseStack) {
      lit = neg_lit(*last_dec);
      last_dec--;
      lits[lits_len] = lit;
      lits_len++;

      if (S->reason[abs(lit)] == 0) {
        last_bvar = lit_to_var(lit);
        break;
      }
    }
#endif
#ifdef MRC
    if (lits_len > 0) {
      if (last_bvar == UNDEF_VAR) {
#ifdef STATS
        bj_tic = clock();
#endif
        mrc_backjump(0, mrc);
#ifdef STATS
        bj_toc = clock();
        bj_f = 1;
#endif
#ifdef STATS
        assign_tic = clock();
#endif
        mrc_assign_lits(lits, lits_len, mrc);
#ifdef STATS
        assign_toc = clock();
        assign_f = 1;
#endif
      } else {
        last_bvar_ass = abs(mrc->var_ass[last_bvar]);

        if (last_bvar_ass) {
#ifdef STATS
          bj_tic = clock();
#endif
          mrc_backjump(last_bvar_ass - 1, mrc);
#ifdef STATS
          bj_toc = clock();
          bj_f = 1;
#endif
#ifdef STATS
          inc_dec_lvl_tic = clock();
#endif
          mrc_increase_decision_level(mrc);
#ifdef STATS
          inc_dec_lvl_toc = clock();
          inc_dec_lvl_f = 1;
#endif
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_assign_lits(lits, lits_len, mrc);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        } else {
#ifdef STATS
          inc_dec_lvl_tic = clock();
#endif
          mrc_increase_decision_level(mrc);
#ifdef STATS
          inc_dec_lvl_toc = clock();
          inc_dec_lvl_f = 1;
#endif
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_assign_lits(lits, lits_len, mrc);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        }
      }
    }
#endif
#ifdef MRC_DYN
    if (lits_len > 0) {
      if (last_bvar == UNDEF_VAR) {
#ifdef STATS
        bj_tic = clock();
#endif
        mrc_dyn_backjump(0, mrc_dyn);
#ifdef STATS
        bj_toc = clock();
        bj_f = 1;
#endif
#ifdef STATS
        assign_tic = clock();
#endif
        mrc_dyn_assign_lits(lits, lits_len, mrc_dyn);
#ifdef STATS
        assign_toc = clock();
        assign_f = 1;
#endif
      } else {
        last_bvar_ass = abs(mrc_dyn->var_ass[last_bvar]);

        if (last_bvar_ass) {
#ifdef STATS
          bj_tic = clock();
#endif
          mrc_dyn_backjump(last_bvar_ass - 1, mrc_dyn);
#ifdef STATS
          bj_toc = clock();
          bj_f = 1;
#endif
#ifdef STATS
          inc_dec_lvl_tic = clock();
#endif
          mrc_dyn_increase_decision_level(mrc_dyn);
#ifdef STATS
          inc_dec_lvl_toc = clock();
          inc_dec_lvl_f = 1;
#endif
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_dyn_assign_lits(lits, lits_len, mrc_dyn);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        } else {
#ifdef STATS
          inc_dec_lvl_tic = clock();
#endif
          mrc_dyn_increase_decision_level(mrc_dyn);
#ifdef STATS
          inc_dec_lvl_toc = clock();
          inc_dec_lvl_f = 1;
#endif
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_dyn_assign_lits(lits, lits_len, mrc_dyn);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        }
      }
    }
#endif
#ifdef MRC_GPU
    if (lits_len > 0) {
      if (last_bvar == UNDEF_VAR) {
#ifdef STATS
        bj_tic = clock();
#endif
        mrc_gpu_backjump(0, d_mrc);
#ifdef STATS
        bj_toc = clock();
        bj_f = 1;
#endif
#ifdef STATS
        assign_tic = clock();
#endif
        mrc_gpu_assign_lits(lits, lits_len, d_mrc);
#ifdef STATS
        assign_toc = clock();
        assign_f = 1;
#endif
      } else {
        gpuErrchk( cudaMemcpy(&last_bvar_ass, &(d_var_ass[last_bvar]),
                              sizeof last_bvar_ass,
                              cudaMemcpyDeviceToHost) );

        last_bvar_ass = abs(last_bvar_ass);

        if (last_bvar_ass) {
#ifdef STATS
          bj_tic = clock();
#endif
          mrc_gpu_backjump(last_bvar_ass - 1, d_mrc);
#ifdef STATS
          bj_toc = clock();
          bj_f = 1;
#endif
#ifdef STATS
          inc_dec_lvl_tic = clock();
#endif
          mrc_gpu_increase_decision_level(d_mrc);
#ifdef STATS
          inc_dec_lvl_toc = clock();
          inc_dec_lvl_f = 1;
#endif
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_gpu_assign_lits(lits, lits_len, d_mrc);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        } else {
#ifdef STATS
          inc_dec_lvl_tic = clock();
#endif
          mrc_gpu_increase_decision_level(d_mrc);
#ifdef STATS
          inc_dec_lvl_toc = clock();
          inc_dec_lvl_f = 1;
#endif
#ifdef STATS
          assign_tic = clock();
#endif
          mrc_gpu_assign_lits(lits, lits_len, d_mrc);
#ifdef STATS
          assign_toc = clock();
          assign_f = 1;
#endif
        }
      }
    }
#endif
#if defined STATS && (defined MRC || defined MRC_DYN || defined MRC_GPU)
  if (bj_f) {
    num_bj++;
    bj_time = ((double)(bj_toc - bj_tic)) / CLOCKS_PER_SEC;   // In s.
    bj_time *= 1000;    // In ms.

    tot_bj_time += bj_time;
    miracle_time += bj_time;

    if (bj_time > max_bj_time) {
      max_bj_time = bj_time;
    }

    if (bj_time < min_bj_time) {
      min_bj_time = bj_time;
    }

    bj_f = 0;
  }

  if (inc_dec_lvl_f) {
    num_inc_dec_lvl++;
    inc_dec_lvl_time = ((double)(inc_dec_lvl_toc - inc_dec_lvl_tic)) / CLOCKS_PER_SEC;  // In s.
    inc_dec_lvl_time *= 1000;   // In ms.

    tot_inc_dec_lvl_time += inc_dec_lvl_time;
    miracle_time += inc_dec_lvl_time;
    
    if (inc_dec_lvl_time > max_inc_dec_lvl_time) {
      max_inc_dec_lvl_time = inc_dec_lvl_time;
    }

    if (inc_dec_lvl_time < min_inc_dec_lvl_time) {
      min_inc_dec_lvl_time = inc_dec_lvl_time;
    }

    inc_dec_lvl_f = 0;
  }

  if (assign_f) {
    num_assign++;
    assign_time = ((double)(assign_toc - assign_tic)) / CLOCKS_PER_SEC;   // In s.
    assign_time *= 1000;    // In ms.

    tot_assign_time += assign_time;
    miracle_time += assign_time;

    if (assign_time > max_assign_time) {
      max_assign_time = assign_time;
    }

    if (assign_time < min_assign_time) {
      min_assign_time = assign_time;
    }

    assign_f = 0;
  }
#endif

#ifdef MRC
#ifdef STATS
    heur_tic = clock();
#endif
    #ifdef JW_OS
    decision = mrc_JW_OS_heuristic(mrc);
    #endif
    #ifdef JW_TS
    decision = mrc_JW_TS_heuristic(mrc);
    #endif
    #ifdef BOHM
    decision = mrc_BOHM_heuristic(mrc, BOHM_alpha, BOHM_beta);
    #endif
    #ifdef POSIT
    decision = mrc_POSIT_heuristic(mrc, POSIT_n);
    #endif
    #ifdef DLIS
    decision = mrc_DLIS_heuristic(mrc);
    #endif
    #ifdef DLCS
    decision = mrc_DLCS_heuristic(mrc);
    #endif
    #ifdef RDLIS
    decision = mrc_RDLIS_heuristic(mrc);
    #endif
    #ifdef RDLCS
    decision = mrc_RDLCS_heuristic(mrc);
    #endif
#ifdef STATS
    heur_toc = clock();
#endif
#endif
#ifdef MRC_DYN
#ifdef STATS
    heur_tic = clock();
#endif
    #ifdef JW_OS
    decision = mrc_dyn_JW_OS_heuristic(mrc_dyn);
    #endif
    #ifdef JW_TS
    decision = mrc_dyn_JW_TS_heuristic(mrc_dyn);
    #endif
    #ifdef BOHM
    decision = mrc_dyn_BOHM_heuristic(mrc_dyn, BOHM_alpha, BOHM_beta);
    #endif
    #ifdef POSIT
    decision = mrc_dyn_POSIT_heuristic(mrc_dyn, POSIT_n);
    #endif
    #ifdef DLIS
    decision = mrc_dyn_DLIS_heuristic(mrc_dyn);
    #endif
    #ifdef DLCS
    decision = mrc_dyn_DLCS_heuristic(mrc_dyn);
    #endif
    #ifdef RDLIS
    decision = mrc_dyn_RDLIS_heuristic(mrc_dyn);
    #endif
    #ifdef RDLCS
    decision = mrc_dyn_RDLCS_heuristic(mrc_dyn);
    #endif
#ifdef STATS
    heur_toc = clock();
#endif
#endif
#ifdef MRC_GPU
#ifdef STATS
    heur_tic = clock();
#endif
    #ifdef JW_OS
    decision = mrc_gpu_JW_OS_heuristic(d_mrc);
    #endif
    #ifdef JW_TS
    decision = mrc_gpu_JW_TS_heuristic(d_mrc);
    #endif
    #ifdef BOHM
    decision = mrc_gpu_BOHM_heuristic(d_mrc, BOHM_alpha, BOHM_beta);
    #endif
    #ifdef POSIT
    decision = mrc_gpu_POSIT_heuristic(d_mrc, POSIT_n);
    #endif
    #ifdef DLIS
    decision = mrc_gpu_DLIS_heuristic(d_mrc);
    #endif
    #ifdef DLCS
    decision = mrc_gpu_DLCS_heuristic(d_mrc);
    #endif
    #ifdef RDLIS
    decision = mrc_gpu_RDLIS_heuristic(d_mrc);
    #endif
    #ifdef RDLCS
    decision = mrc_gpu_RDLCS_heuristic(d_mrc);
    #endif
#ifdef STATS
    heur_toc = clock();
#endif
#endif

#ifdef NO_MRC
#ifdef STATS
    heur_tic = clock();
#endif
    while (S->falselit[decision] || S->falselit[-decision]) {       // As long as the temporary decision is assigned
      decision = S->prev[decision]; }                               // Replace it with the next variable in the decision list
    decision = S->model[decision] ? decision : -decision;           // Assign the decision variable based on the model
#ifdef STATS
    heur_toc = clock();
#endif
    if (decision == 0) return SAT;                                  // If the end of the list is reached, then a solution is found
    S->falselit[-decision] = 1;                                     // Assign the decision literal to true (change to IMPLIED-1?)
    *(S->assigned++) = -decision;                                   // And push it on the assigned stack
    decision = abs(decision); S->reason[decision] = 0;              // Decisions have no reason clauses
#endif
#if defined MRC || defined MRC_DYN || defined MRC_GPU
    if (decision == UNDEF_LIT) {
      return SAT;
    }

    S->falselit[-decision] = 1;
    *(S->assigned++) = -decision;
    S->model[abs(decision)] = decision > 0 ? 1 : 0;
    decision = abs(decision); S->reason[decision] = 0;
#endif

#ifdef STATS
    num_heur++;
    heur_time = ((double)(heur_toc - heur_tic)) / CLOCKS_PER_SEC;    // In s.
    heur_time *= 1000;   // In ms.

    tot_heur_time += heur_time;
#if defined MRC || defined MRC_DYN || defined MRC_GPU
    miracle_time += heur_time;
#endif

    if (heur_time > max_heur_time) {
      max_heur_time = heur_time;
    }

    if (heur_time < min_heur_time) {
      min_heur_time = heur_time;
    }
#endif
  }
}

void initCDCL (struct solver* S, int n, int m) {
  if (n < 1)      n = 1;                  // The code assumes that there is at least one variable
  S->nVars          = n;                  // Set the number of variables
  S->nClauses       = m;                  // Set the number of clauases
  S->mem_used       = 0;                  // The number of integers allocated in the DB
#ifdef STATS
  mem_used = S->mem_used;
#endif
  S->nLemmas        = 0;                  // The number of learned clauses -- redundant means learned
  S->nConflicts     = 0;                  // Number of conflicts which is used to updates scores
#ifdef STATS
  nConflicts = S->nConflicts;
#endif
  S->maxLemmas      = 2000;               // Initial maximum number of learnt clauses
#ifdef STATS
  maxLemmas = S->maxLemmas;
#endif
  S->fast = S->slow = 1 << 24;            // Initialize the fast and slow moving averages
  S->nRestarts      = 0;                  // The number of restarts performed
#ifdef STATS
  nRestarts = S->nRestarts;
#endif

  S->DB = (int *) malloc (sizeof (int) * MEM_MAX); // Allocate the initial database
  S->model       = getMemory (S, n+1); // Full assignment of the (Boolean) variables (initially set to false)
#ifdef NO_MRC
  S->next        = getMemory (S, n+1); // Next variable in the heuristic order
  S->prev        = getMemory (S, n+1); // Previous variable in the heuristic order
#endif
  S->buffer      = getMemory (S, n  ); // A buffer to store a temporary clause
  S->reason      = getMemory (S, n+1); // Array of clauses
  S->falseStack  = getMemory (S, n+1); // Stack of falsified literals -- this pointer is never changed
  S->forced      = S->falseStack;      // Points inside *falseStack at first decision (unforced literal)
  S->processed   = S->falseStack;      // Points inside *falseStack at first unprocessed literal
  S->assigned    = S->falseStack;      // Points inside *falseStack at last unprocessed literal
  S->falselit    = getMemory (S, 2*n+1); S->falselit += n; // Labels for variables, non-zero means false
  S->first       = getMemory (S, 2*n+1); S->first += n; // Offset of the first watched clause
  S->DB[S->mem_used++] = 0;            // Make sure there is a 0 before the clauses are loaded.
#ifdef STATS
  mem_used = S->mem_used;
#endif

  int i; for (i = 1; i <= n; i++) {                        // Initialize the main datastructures:
#ifdef NO_MRC
    S->prev [i] = i - 1; S->next[i-1] = i;                 // the double-linked list for variable-move-to-front,
#endif
    S->model[i] = S->falselit[-i] = S->falselit[i] = 0;    // the model (phase-saving), the falselit array,
    S->first[i] = S->first[-i] = END; }                    // and first (watch pointers).
#ifdef NO_MRC
  S->head = n;                                             // Initialize the head of the double-linked list
#endif
}

static void read_until_new_line (FILE * input) {
  int ch;
  while ((ch = getc (input)) != '\n')
    if (ch == EOF) { printf ("parse error: unexpected EOF"); exit (1); }
}

int parse (struct solver* S, char* filename) {                            // Parse the formula and initialize
  int tmp; FILE* input; int close = 1;
  if (strcmp (filename + strlen (filename) - 3, ".xz"))
    input = fopen (filename, "r");					  // Open file
  else { char * cmd = (char *)malloc (strlen (filename) + 20);
    sprintf (cmd, "xz -c -d %s", filename);
    input = popen (cmd, "r"); close = 2; free (cmd); }		          // Open pipe
  while ((tmp = getc (input)) == 'c')
    read_until_new_line (input);
  ungetc (tmp, input);
  do { tmp = fscanf (input, "p cnf %d %d", &S->nVars, &S->nClauses);  // Find the first non-comment line
    if (tmp > 0 && tmp != EOF) break; tmp = fscanf (input, "%*s\n"); }    // In case a commment line was found
  while (tmp != 2 && tmp != EOF);                                         // Skip it and read next line

  initCDCL (S, S->nVars, S->nClauses);                     // Allocate the main datastructures
  int nZeros = S->nClauses, size = 0;                      // Initialize the number of clauses to read
  while (nZeros > 0) {                                     // While there are clauses in the file
    int ch = getc (input);
    if (ch == ' ' || ch == '\n') continue;
    if (ch == 'c') { read_until_new_line (input); continue; }
    ungetc (ch, input);
    int lit = 0; tmp = fscanf (input, " %i ", &lit);          // Read a literal.
    if (!lit) {                                               // If reaching the end of the clause
      int* clause = addClause (S, S->buffer, size, 1);        // Then add the clause to data_base
      if (!size || ((size == 1) && S->falselit[clause[0]]))   // Check for empty clause or conflicting unit
        return UNSAT;                                         // If either is found return UNSAT
      if ((size == 1) && !S->falselit[-clause[0]]) {          // Check for a new unit
        assign (S, clause, 1); }                              // Directly assign new units (forced = 1)
      size = 0; --nZeros; }                                   // Reset buffer
    else S->buffer[size++] = lit; }                           // Add literal to buffer
  if (close == 1) fclose (input);                             // Close the formula file
  if (close == 2) pclose (input);                             // Close the formula pipe
  return SAT; }                                               // Return that no conflict was observed

/**
 * Display the result of the solver
 */
void show_result(struct solver* S, int result) {
  if (result == SAT) {    // if the formula is satisfiable
    printf("SAT\n");

    for (int v = 1; v <= S->nVars; v++) {
      if (S->model[v] == 0) {
        printf("%d ", -v);
      } else {
        printf("%d ", v);
      }
    }

    printf("0\n");
  } else {                // if the formula is unsatisfiable
    printf("UNSAT\n");
  }
}

int main (int argc, char** argv) {			                      // The main procedure for a STANDALONE solver
  if (argc < 2) abort ();

#ifdef STATS
  filename = argv[1];
#endif
  
  struct solver S;	                                          // Create the solver datastructure

  if (parse (&S, argv[1]) == UNSAT) {                         // Parse the DIMACS file in argv[1]
    show_result(&S, UNSAT);
  } else {
#ifdef POSIT
    POSIT_n = POSIT_N;
#endif
#ifdef BOHM
    BOHM_alpha = BOHM_ALPHA;
    BOHM_beta = BOHM_BETA;
#endif
#if defined MRC || defined MRC_DYN || defined MRC_GPU
    lits = (Lit *)malloc(sizeof *lits * S.nVars);
    lits_len = 0;
#endif
#ifdef STATS
#if defined MRC || defined MRC_DYN || defined MRC_GPU
    miracle_time = 0;

    max_inc_dec_lvl_time = -DBL_MAX;
    min_inc_dec_lvl_time = DBL_MAX;
    tot_inc_dec_lvl_time = 0;
    num_inc_dec_lvl = 0;
    inc_dec_lvl_f = 0;

    max_assign_time = -DBL_MAX;
    min_assign_time = DBL_MAX;
    tot_assign_time = 0;
    num_assign = 0;
    assign_f = 0;

    max_bj_time = -DBL_MAX;
    min_bj_time = DBL_MAX;
    tot_bj_time = 0;
    num_bj = 0;
    bj_f = 0;
#endif

    max_heur_time = -DBL_MAX;
    min_heur_time = DBL_MAX;
    tot_heur_time = 0;
    num_heur = 0;

    timeout_expired = 0;
    escape = 0;
    timeout = TIMEOUT;   // In s.

    // Set SIGINT handler.
    install_handler();

    // Set SIGALRM handler.
    install_alarmhandler();
#endif

#ifdef NO_MRC
#ifdef STATS
    alarm(timeout);
    solve_tic = clock();
#endif
    int slv = solve (&S);                                       // Solve without limit (number of conflicts)
#ifdef STATS
    solve_toc = clock();
#endif
#endif
#ifdef MRC
    Miracle *mrc = mrc_create_miracle(argv[1]);

#ifdef STATS
    alarm(timeout);
    solve_tic = clock();
#endif
    int slv = solve (&S, mrc);
#ifdef STATS
    solve_toc = clock();
#endif

    mrc_destroy_miracle(mrc);
#endif
#ifdef MRC_DYN
    Miracle_Dyn *mrc_dyn = mrc_dyn_create_miracle(argv[1]);

#ifdef STATS
    alarm(timeout);
    solve_tic = clock();
#endif
    int slv = solve (&S, mrc_dyn);
#ifdef STATS
    solve_toc = clock();
#endif

    mrc_dyn_destroy_miracle(mrc_dyn);
#endif
#ifdef MRC_GPU
    num_threads_per_block = NUM_THREADS_PER_BLOCK;
    gpu_set_device(0);
    gpu_set_num_threads_per_block(num_threads_per_block);

    Miracle *mrc = mrc_create_miracle(argv[1]);
    Miracle *d_mrc = mrc_gpu_transfer_miracle_host_to_dev(mrc);

    gpuErrchk( cudaMemcpy(&d_var_ass, &(d_mrc->var_ass),
                          sizeof d_var_ass,
                          cudaMemcpyDeviceToHost) );

#ifdef STATS
    alarm(timeout);
    solve_tic = clock();
#endif
    int slv = solve (&S, d_mrc);
#ifdef STATS
    solve_toc = clock();
#endif

    mrc_destroy_miracle(mrc);
    mrc_gpu_destroy_miracle(d_mrc);
#endif

    if (slv == UNSAT) {                                         // Print whether the formula has a solution
      show_result(&S, UNSAT);
    } else {
      show_result(&S, SAT);
    }
  }

  printf ("\n");
  printf ("c statistics of %s: mem: %i conflicts: %i max_lemmas: %i restarts: %i\n", argv[1], S.mem_used, S.nConflicts, S.maxLemmas, S.nRestarts);

#ifdef STATS
  solving_time = ((double)(solve_toc - solve_tic)) / CLOCKS_PER_SEC;    // In s.
  solving_time *= 1000;   // In ms.

  printf("\n");
  print_stats();
#endif

  return 0;
}
