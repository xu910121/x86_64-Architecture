## Memory Type

​	MTRR（Memory Type Range Register），作用是将memory物理地址划分为某些区域，并且可以为这些区域定义不同的memory类型。

**术语解释**

​	Cache Line Fill：当processor读一块memory并且发现这块memory是cacheable的（通过MTRR来决定该块memory是否cacheable），那么processor会把整个Cache Line读取到L1，L2或L3的cache中。

​	Cache hit：当处理器要读取一块memory的内容时，发现这块内容已经存在cache中了，那么这就称为cache hit

​	Write hit：当处理器要写内容到一块memory时，发现cache中已经有这块memory对应的cache了，那么就叫做write hit。它会先写到cache，再根据当前系统的写决策决定是否要同时写到memory。

------

### Cache Type（Memory Type）

<!--此处Intel手册写Cache Type又叫Memory Type-->

Memory Types and Their Properties

| Memory Type and Mnemonic | Cacheable                   | Writeback Cacheable | Allows Speculative Reads | Memory Ordering Model                                        |
| ------------------------ | --------------------------- | ------------------- | ------------------------ | ------------------------------------------------------------ |
| Strong Uncacheable（UC） | No                          | No                  | No                       | Strong Ordering                                              |
| Uncacheable（UC-）       | No                          | No                  | No                       | Strong Ordering. Can only be selected through the PAT. Can be overridden by WC in MTRRs. |
| Write Combining（WC）    | No                          | No                  | Yes                      | Weak Ordering. Available by programming MTRRs or by selecting it through PAT. |
| Write Through（WT）      | Yes                         | No                  | Yes                      | Speculative Processor Ordering.                              |
| Write Back（WB）         | Yes                         | Yes                 | Yes                      | Speculative Processor Ordering.                              |
| Write Protected （WP）   | Yes for reads;no for writes | No                  | Yes                      | Speculative Processor Ordering.Available by programming MTRRs. |

​	__Strong Uncacheable（UC）__：对于UC的内存读写操作都不会写到Cache里，不会被reordering。这种类型的内存适合用于memory-mapped I/O device，比如说集成显卡。对于别memory-mapped I/O device使用的内存，由于会被CPU和I/O device同时访问，那么CPU的cache就会导致一致性问题（Note），reordering也会导致I/O device读到dirty data，比如说I/O device把这些内存作为一些控制用的寄存器使用。

​	对于普通用途的内存，UC会导致性能的急剧下降。

​	Note：一种例外是，有些I/O device支持bus coherency protocol，可以和CPU保持cache一致性，这样的话是可以使用cacheable的内存的，但是这种总线协议也是有代价的。

​	__Uncacheable（UC-）__：和UC类型一样，除了UC- memory type可以通过设置MTRRs被改写成WC memory type。

​	__Write Combining（WC）__：WC内存不会被cache，bus coherency protocol 不会保证WC内存的读写。对于WC类型的写操作，可能会被延迟，数据被combined in write combining buffer， 这样可以减少总线上的访存操作。Speculative reads are allowed（Note）。对于video frame buffer，适合使用WC类型的内存。因为CPU对于frame buffer一般只有写操作，没有读，并不需要cache。对frame buffer而言，写操作是否按顺序没有关系。

​	Note：Speculative read是指读之前并不验证内存的有效性，先冒险的读进来，如果发现不是有效数据再取消读取操纵，并更新内存后再读取，比如说数据还是被buffer在WC buffer中。

​	__Write-through (WT)__：适用于bus上的设备只读取内存而不需要写

​	**Write-back(WB)**：最普通的只会被CPU使用的内存，由于write操作是在cache中进行的，只有必要的时候才会被写回memory，可减少bus上的压力。

​	**Write Protected（WP）**：读操作和WT/WB没有什么区别，读会被cache，写不一样，写的时候会在bus上传播这个操作，并且导致其他处理器上的cache line被更新。

​	重要用于多处理器的情况。WP的内存，在写的时候就会更新其他处理器上测cache，而WT/WB类型的内存需要等到其他处理器读的时候才会去更新无效的cache。















































































































































































