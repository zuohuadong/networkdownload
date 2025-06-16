FROM ahmadalsajid/oha-docker:latest

ENV th=2
ENV url=http://img.cmvideo.cn/publish/noms/2022/10/14/1O3VIGPVP6HTS.jpg

ENTRYPOINT ["sh", "-c","oha -n 1000000000000000 -c ${th} ${url} "]