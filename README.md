# networkdownload

Rust 版 networkdown    
运行： docker run zuohuadong/networkdownload    

## 环境变量
`th` 线程数，默认为`2`    
`time` 时间，默认为`2147483647sec`  (bun 版无需设置）    
`url` 拉流链接，有内置，可自行更换。     
`ui` 输出日志，默认不输出，需要输出请将该项改为空。



## 版本说明    

latest/rust 版本：占用内存小，性能好。    
alpine 版本：体积小，性能好。    
bun/nodejs 版本：兼容性好，默认使用 bun 优化性能。
 
