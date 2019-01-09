GDT和LDT中，load段选择子，段选择子哪里来？段寄存器多少位？

0x000080000000到0xFFFF7FFFFFFFFFFF为什么是非法的non-canonical地址？**done**，因为去掉前面的0000或FFFF，80000000到7FFFFFFFFFFF与高位的重复了。

0xFFFFFFFF_FFFFFFFFF

0xFFFF8000_00000000

0xFFFF7FFF_FFFFFFFF

0x0000~~8000_00000000~~



**远指针**？？？？？？？？？？？？？



<u>64位模式下，除了FS与GS段可以使用非0值得Base外，其余的ES、CS、DS、及SS段的base强制为0值。因此，实际上的线性地址就是代码中的offset值。</u>

**何为64位模式？**

64位，到底指什么是64位的？cpu通用寄存器还是数据总线、或者什么总线？如果数据总线不是64位，那现在的是多少？



在一个程序中，某一个段选择器的base是不是定值？不同程序，同一个段选择器，比如CS，其base值不同？



段限制字段，是一个20bit的值，那这个20bit的值可以把段限制在1byte-1MByte，或者4kBytes-4GBytes，步长为4KByte。需要看段描述符中G位。也就是段的大小最多只能是4G？



**异常**

何为trap类型的异常？？？

eflags.RF作用？标志是trap类异常，然后让iret返回时，弹出eflags？？？？





CR0.TS配合CR0.MP使用，在进程切换完毕后，在新进程的执行过程中，遇到第一条x87 FPU/MMX/SSE以及AVX指令执行时进行监控，产生#NM异常。

这里怎么确定这第一条FPU/MMX/SSE以及AVX指令是上一进程的或是当前进程的？