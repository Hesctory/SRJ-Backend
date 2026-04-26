using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EducationalPerson
{
    public int PersonId { get; set; }

    public int? EthnicSelfIdentificationId { get; set; }

    public int NativeLanguageId { get; set; }

    public virtual EthnicSelfIdentification? EthnicSelfIdentification { get; set; }

    public virtual Familiar? Familiar { get; set; }

    public virtual Language NativeLanguage { get; set; } = null!;

    public virtual Person Person { get; set; } = null!;

    public virtual Student? Student { get; set; }

    public virtual ICollection<Language> SecondLanguages { get; set; } = new List<Language>();
}
