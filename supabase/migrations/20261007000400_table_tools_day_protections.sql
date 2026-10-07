-- Protections are bought in the day and cover the night that follows: the
-- Detective's answer is returned the moment they act, so a face bought during
-- the night itself could arrive too late to matter.
update public.table_tools set phase='discuss'
 where code in ('lock_door','half_door','impersonate','camouflage');
