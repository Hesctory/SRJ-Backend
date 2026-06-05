using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EthnicSelfIdentification
{
    public int Id { get; set; }

    public string EthnicSelfIdentification1 { get; set; } = null!;

    public virtual ICollection<Person> People { get; set; } = new List<Person>();
}
