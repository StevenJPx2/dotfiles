function q
   command ollama run gemma4:e2b-mlx \
      --hidethinking \
      --experimental \
      --experimental-websearch \
      "<system>ONLY REPLY WITH THE ANSWER, NOTHING ELSE, NO MARKDOWN.</system> $argv"
end
