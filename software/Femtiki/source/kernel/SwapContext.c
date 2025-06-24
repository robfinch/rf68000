// ----------------------------------------------------------------------------
// Restore the thread's context.
// ----------------------------------------------------------------------------

void SwapContext(register TCB *octx, register TCB *nctx)
{
	int n;
	int th;

	octx->regs[1] = GetRegx1();
	octx->regs[2] = GetRegx2();
	octx->regs[3] = GetRegx3();
	octx->regs[4] = GetRegx4();
	octx->regs[5] = GetRegx5();
	octx->regs[6] = GetRegx6();
	octx->regs[7] = GetRegx7();
	octx->regs[8] = GetRegx8();
	octx->regs[9] = GetRegx9();
	octx->regs[10] = GetRegx10();
	octx->regs[11] = GetRegx11();
	octx->regs[12] = GetRegx12();
	octx->regs[13] = GetRegx13();
	octx->regs[14] = GetRegx14();
	octx->regs[15] = GetRegx15();
	SetRegx1(nctx->regs[1]);
	SetRegx2(nctx->regs[2]);
	SetRegx3(nctx->regs[3]);
	SetRegx4(nctx->regs[4]);
	SetRegx5(nctx->regs[5]);
	SetRegx6(nctx->regs[6]);
	SetRegx7(nctx->regs[7]);
	SetRegx8(nctx->regs[8]);
	SetRegx9(nctx->regs[9]);
	SetRegx10(nctx->regs[10]);
	SetRegx11(nctx->regs[11]);
	SetRegx12(nctx->regs[12]);
	SetRegx13(nctx->regs[13]);
	SetRegx14(nctx->regs[14]);
	SetRegx15(nctx->regs[15]);
}

