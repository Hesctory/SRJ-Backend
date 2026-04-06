using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EthnicSelfIdentification
{
    public int Id { get; set; }

    public string? EthnicSelfIdentification1 { get; set; }

    public virtual ICollection<EducationalPerson> EducationalPeople { get; set; } = new List<EducationalPerson>();
}
