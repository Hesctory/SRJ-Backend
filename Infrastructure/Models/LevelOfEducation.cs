using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class LevelOfEducation
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<Familiar> Familiars { get; set; } = new List<Familiar>();

    public virtual ICollection<StaffMember> StaffMembers { get; set; } = new List<StaffMember>();
}
