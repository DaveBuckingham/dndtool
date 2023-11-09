FROM perl:5.34

RUN cpanm REST::Client
RUN cpanm JSON
RUN cpanm Term::ReadKey
RUN cpanm Term::ReadLine::Gnu

RUN apt update && apt install less

COPY . /usr/src/myapp
WORKDIR /usr/src/myapp

CMD [ "perl", "./dndtool.pl" ]
