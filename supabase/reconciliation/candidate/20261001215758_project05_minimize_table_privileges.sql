-- Keep direct row deletion available only where the product currently needs it.
revoke delete on table
  public.profiles,
  public.applications,
  public.ai_sessions
from authenticated;



