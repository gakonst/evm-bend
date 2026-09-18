// Crypto-only process effect. tmpfile streams avoid pipe deadlocks for large IO.
#include <sys/wait.h>
#include <unistd.h>
static void precompile_host_call(IoWork* w) {
  FILE* in = tmpfile();
  FILE* out = tmpfile();
  const char* path = getenv("BEND_EVM_PRECOMPILE_HOST");
  w->code = 1;
  if (!in || !out || !path || path[0] != '/') goto done;
  if (fwrite(w->data, 1, w->size, in) != w->size || fflush(in) || fseek(in, 0, SEEK_SET)) goto done;
  pid_t pid = fork();
  if (pid == 0) {
    if (dup2(fileno(in), STDIN_FILENO) < 0 || dup2(fileno(out), STDOUT_FILENO) < 0) _exit(126);
    execl(path, path, (char*)NULL);
    _exit(127);
  }
  if (pid < 0) goto done;
  int status;
  pid_t waited;
  do { waited = waitpid(pid, &status, 0); } while (waited < 0 && errno == EINTR);
  if (waited != pid || !WIFEXITED(status) || WEXITSTATUS(status) != 0) goto done;
  if (fseek(out, 0, SEEK_END)) goto done;
  long size = ftell(out);
  if (size < 9 || size > 256L * 1024 * 1024 || fseek(out, 0, SEEK_SET)) goto done;
  w->data = io_mem(realloc(w->data, (size_t)size));
  w->size = (u64)size;
  if (fread(w->data, 1, w->size, out) != w->size || ((unsigned char*)w->data)[0] > 2) goto done;
  w->code = 0;
done:
  if (in) fclose(in);
  if (out) fclose(out);
}
static Term precompile_host_pack(Env e, IoWork* w) {
  Term xs = term_pak(CID_NIL, 0);
  if (w->code) {
    for (int i = 0; i < 8; ++i) xs = io_node(e, CID_CON, 0, xs, IO_HOTS & 16);
    xs = io_node(e, CID_CON, 2, xs, IO_HOTS & 16);
  } else {
    for (u64 i = w->size; i > 0; --i) xs = io_node(e, CID_CON, ((unsigned char*)w->data)[i-1], xs, IO_HOTS & 16);
  }
  free(w->data);
  return xs;
}
Term precompile_host_run(Env e, Term* f, IoWork* w) {
  size_t cap = 64;
  w->size = 0;
  w->data = io_mem(malloc(cap));
  Term xs = f[0];
  int invalid = 0;
  while (term_aux(xs) == CID_CON) {
    Term fields[2];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, fields));
    if (fields[0] > 255) invalid = 1;
    if (w->size == cap) { cap *= 2; w->data = io_mem(realloc(w->data, cap)); }
    ((unsigned char*)w->data)[w->size++] = (unsigned char)fields[0];
    xs = fields[1];
  }
  if (invalid) { w->code = 1; return precompile_host_pack(e, w); }
  return io_work(w, precompile_host_call, precompile_host_pack);
}
static void __attribute__((constructor)) precompile_host_use(void) {
  io_eff(CID_PRECOMPILE_HOST, precompile_host_run, 0);
}
