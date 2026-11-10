function authorizationLabel(message) {
  var text = String(message || "").trim();
  if (!text) return "Authentication Required";
  var match = text.match(/^Authentication is (?:needed|required) to run [`']?([^`']+)['`]? as /i);
  if (match) return "Authorize running '" + match[1] + "'";
  match = text.match(/^Authentication is (?:needed|required) to ([^.]+)/i);
  if (match) return "Authorize: " + match[1].trim();
  return text.endsWith(".") ? text.slice(0, -1) : text;
}
