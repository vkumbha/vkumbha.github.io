---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: true
{{ if .Params.tags }}
  <div class="post-tags">
    <strong>Tags:</strong>
    {{ range .Params.tags }}
      <a href="{{ "/tags/" | relLangURL }}{{ . | urlize }}">{{ . }}</a>
    {{ end }}
  </div>
{{ end }}
---
