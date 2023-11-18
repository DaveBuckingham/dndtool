FROM perl:5.38

WORKDIR /app

COPY ./dndtool.pl ./
COPY ./VERSION ./

RUN apt update && apt install -y less bc

RUN cpanm Term::ReadLine::Gnu
RUN cpanm REST::Client
RUN cpanm JSON
RUN cpanm Number::Format

CMD [ "perl", "dndtool.pl" ]
